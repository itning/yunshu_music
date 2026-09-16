import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:music_platform_interface/encryption_tool.dart';
import 'package:music_platform_interface/music_model.dart';
import 'package:music_platform_interface/music_platform_interface.dart';
import 'package:music_platform_interface/music_play_mode.dart';
import 'package:music_platform_interface/music_status.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

import 'ffmpeg_player.dart';

class MusicChannelWindows extends MusicPlatform {
  static void registerWith() {
    MusicPlatform.instance = MusicChannelWindows();
  }

  static const MethodChannel _channel = MethodChannel('music_channel_windows');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static const String _nowPlayMusicIdKey = "NOW_PLAY_MEDIA_ID_KEY";
  static const String _playModeKey = "PLAY_MODE";
  static const String _playListKey = "PLAY_LIST";

  /// 托盘图标资源（相对于 flutter_assets）
  static const String _trayIconAsset = "asserts/icon/app_icon.ico";

  /// 托盘菜单项 ID
  static const int _trayMenuShow = 1;
  static const int _trayMenuPrevious = 2;
  static const int _trayMenuNext = 3;
  static const int _trayMenuPlayStatus = 4;
  static const int _trayMenuExit = 5;

  /// 播放实例
  late FfmpegPlayer _player;

  /// 播放元数据信息：歌曲信息，时长等。
  late StreamController<dynamic> _metadataEventController;

  /// 播放状态信息：是否播放，播放进度，缓冲进度
  late StreamController<dynamic> _playbackStateController;

  /// 音量信息
  late StreamController<double> _volumeController;

  /// 数据落地
  late SharedPreferences _sharedPreferences;

  /// 播放列表指针
  late int _nowPlayIndex;

  /// 播放模式
  late MusicPlayMode _playMode;

  /// 音乐列表
  final List<Music> _musicList = [];

  /// 播放列表
  final List<Music> _playList = [];

  /// 元数据载体
  final MusicMetaData _metaData = MusicMetaData();

  /// 播放状态载体
  final PlaybackState _playbackState = PlaybackState();

  /// 随机过的音乐信息
  final Set<Music> _randomSet = {};

  /// 正在播放的音乐信息
  Music? _nowPlayMusic;

  bool _isPlayNow = false;

  late Map<String, dynamic> _authorizationData;

  /// SMTC 时间轴（毫秒）
  int _smtcPositionMs = 0;
  int _smtcEndMs = 0;

  /// 播放模式变更事件（系统媒体控件触发时通知 App）
  final StreamController<dynamic> _playModeEventController =
      StreamController<dynamic>.broadcast();

  @override
  Stream<dynamic> get playModeEvent => _playModeEventController.stream;

  @override
  Future<void> init(
    StreamController<dynamic> metadataEventController,
    StreamController<dynamic> playbackStateController,
    StreamController<double> volumeController,
  ) async {
    await _channel.invokeMethod('smtcInit');
    _setWindowTitle("云舒音乐");
    await _channel.invokeMethod('windowSetMinimumSize', {
      'width': 450.0,
      'height': 900.0,
    });

    _metadataEventController = metadataEventController;
    _playbackStateController = playbackStateController;
    _volumeController = volumeController;
    _sharedPreferences = await SharedPreferences.getInstance();

    _nowPlayIndex = -1;
    _playMode = valueOf(
      _sharedPreferences.getString(_playModeKey) ?? 'SEQUENCE',
    );
    _syncSmtcPlayMode(_playMode);

    _player = FfmpegPlayer();

    _channel.setMethodCallHandler(_handleNativeCall);

    _player.onPositionChanged.listen((Duration event) {
      int position = event.inMilliseconds;
      _playbackState.position = position;
      playbackStateController.sink.add(_playbackState.toMap());
      _isWindowVisible().then((visible) {
        if (visible) {
          WindowsTaskbar.setProgress(position, _metaData.duration);
        }
      });
      _smtcPositionMs = position;
      _updateSmtcTimeline();
    });

    _player.onPlayerStateChanged.listen((bool playing) {
      _playbackState.state = playing ? MusicStatus.playing : MusicStatus.paused;
      playbackStateController.sink.add(_playbackState.toMap());
      _isWindowVisible().then((visible) {
        if (visible) {
          WindowsTaskbar.setProgressMode(
            playing ? TaskbarProgressMode.normal : TaskbarProgressMode.paused,
          );
        }
      });
      _setSmtcPlaybackStatus(playing ? 'playing' : 'paused');
      _isPlayNow = playing;
      _upContextMenu();
    });

    _player.onPrepared.listen((Duration? duration) {
      if (null != duration) {
        int ms = duration.inMilliseconds;
        _metaData.duration = ms;
        metadataEventController.sink.add(_metaData.toMap());
        _isWindowVisible().then((visible) {
          if (visible) {
            WindowsTaskbar.setProgress(_playbackState.position, ms);
          }
        });
        _smtcEndMs = ms;
        _updateSmtcTimeline();
      }
    });

    _player.onComplete.listen((_) {
      _playbackState.state = MusicStatus.none;
      _playbackStateController.sink.add(_playbackState.toMap());
      _isWindowVisible().then((visible) {
        if (visible) {
          WindowsTaskbar.setProgressMode(TaskbarProgressMode.noProgress);
        }
      });
      _setSmtcPlaybackStatus('stopped');
      next(false);
      initPlay(autoStart: true);
    });

    _playbackState.state = MusicStatus.none;

    await _channel.invokeMethod('traySetIcon', {'iconPath': _trayIconAsset});
    await _channel.invokeMethod('traySetContextMenu', {
      'items': _buildTrayMenu(),
    });
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onTrayIconMouseDown':
        final bool visible = await _isWindowVisible();
        final bool minimized = await _isWindowMinimized();
        if (visible && !minimized) {
          await _hideWindow();
        } else {
          await _showWindow();
        }
        break;
      case 'onTrayIconRightMouseDown':
        await _channel.invokeMethod('trayPopUpContextMenu');
        break;
      case 'onTrayMenuItemClick':
        final dynamic arguments = call.arguments;
        if (arguments is Map && arguments['id'] is int) {
          await _onTrayMenuItemClick(arguments['id'] as int);
        }
        break;
      case 'onSmtcButton':
        final dynamic arguments = call.arguments;
        if (arguments is Map && arguments['button'] is String) {
          await _onSmtcButton(arguments['button'] as String);
        }
        break;
      case 'onSmtcSeek':
        final dynamic arguments = call.arguments;
        if (arguments is Map && arguments['position'] is int) {
          await seekTo(Duration(milliseconds: arguments['position'] as int));
        }
        break;
      case 'onSmtcShuffle':
        final dynamic arguments = call.arguments;
        if (arguments is Map && arguments['enabled'] is bool) {
          await _applyPlayMode(
            (arguments['enabled'] as bool)
                ? MusicPlayMode.RANDOMLY
                : MusicPlayMode.SEQUENCE,
          );
        }
        break;
      case 'onSmtcRepeat':
        final dynamic arguments = call.arguments;
        if (arguments is Map && arguments['mode'] is String) {
          await _applyPlayMode(
            (arguments['mode'] as String) == 'none'
                ? MusicPlayMode.SEQUENCE
                : MusicPlayMode.LOOP,
          );
        }
        break;
      default:
        break;
    }
  }

  /// 系统媒体控件改变了播放模式：同步到 App。
  Future<void> _applyPlayMode(MusicPlayMode mode) async {
    await setPlayMode(mode.name().toLowerCase());
    _playModeEventController.add(mode.name().toLowerCase());
  }

  Future<void> _onSmtcButton(String button) async {
    switch (button) {
      case 'play':
        await play();
        break;
      case 'pause':
        await pause();
        break;
      case 'next':
        await skipToNext();
        break;
      case 'previous':
        await skipToPrevious();
        break;
      case 'stop':
        await pause();
        break;
      default:
        break;
    }
  }

  Future<void> _onTrayMenuItemClick(int id) async {
    switch (id) {
      case _trayMenuShow:
        await _showWindow();
        break;
      case _trayMenuPrevious:
        await skipToPrevious();
        break;
      case _trayMenuNext:
        await skipToNext();
        break;
      case _trayMenuPlayStatus:
        if (_isPlayNow) {
          await pause();
        } else {
          await play();
        }
        break;
      case _trayMenuExit:
        await _channel.invokeMethod('smtcDisable');
        await _player.dispose();
        exit(0);
      default:
        break;
    }
  }

  String _trayTitleLabel() {
    final String title = _metaData.title;
    final String subTitle = _metaData.subTitle;
    if (title.isEmpty && subTitle.isEmpty) {
      return '云舒音乐';
    }
    if (title.isEmpty) {
      return subTitle;
    }
    if (subTitle.isEmpty) {
      return title;
    }
    return '$title - $subTitle';
  }

  List<Map<String, dynamic>> _buildTrayMenu() {
    return [
      {'id': _trayMenuShow, 'label': _trayTitleLabel(), 'separator': false},
      {'id': 0, 'label': '', 'separator': true},
      {'id': _trayMenuPrevious, 'label': '上一曲', 'separator': false},
      {'id': _trayMenuNext, 'label': '下一曲', 'separator': false},
      {
        'id': _trayMenuPlayStatus,
        'label': _isPlayNow ? '暂停' : '播放',
        'separator': false,
      },
      {'id': 0, 'label': '', 'separator': true},
      {'id': _trayMenuExit, 'label': '退出', 'separator': false},
    ];
  }

  void _upContextMenu() {
    _channel.invokeMethod('traySetContextMenu', {'items': _buildTrayMenu()});
  }

  Future<void> _setWindowTitle(String title) async {
    await _channel.invokeMethod('windowSetTitle', {'title': title});
  }

  Future<bool> _isWindowVisible() async {
    final bool? visible = await _channel.invokeMethod('windowIsVisible');
    return visible ?? false;
  }

  Future<bool> _isWindowMinimized() async {
    final bool? minimized = await _channel.invokeMethod('windowIsMinimized');
    return minimized ?? false;
  }

  Future<void> _showWindow() async {
    await _channel.invokeMethod('windowShow');
  }

  Future<void> _hideWindow() async {
    await _channel.invokeMethod('windowHide');
  }

  Future<void> _setSmtcMetadata(String title, String artist) async {
    await _channel.invokeMethod('smtcSetMetadata', {
      'title': title,
      'artist': artist,
    });
  }

  Future<void> _setSmtcPlaybackStatus(String status) async {
    await _channel.invokeMethod('smtcSetPlaybackStatus', {'status': status});
  }

  void _updateSmtcTimeline() {
    _channel.invokeMethod('smtcSetTimeline', {
      'position': _smtcPositionMs,
      'end': _smtcEndMs,
    });
  }

  void initPlay({bool autoStart = false}) {
    if (_nowPlayMusic == null) {
      return;
    }
    if (_nowPlayMusic!.musicUri == null) {
      return;
    }
    _playbackState.state = MusicStatus.connecting;
    _playbackStateController.sink.add(_playbackState.toMap());
    _isWindowVisible().then((visible) {
      if (visible) {
        WindowsTaskbar.setProgressMode(TaskbarProgressMode.indeterminate);
      }
    });

    String url = _nowPlayMusic!.musicUri!;
    if (_authorizationData["ENABLE"]) {
      url = sign(
        url: _nowPlayMusic!.musicUri!,
        pkey: _authorizationData['SIGN'],
        signParamName: _authorizationData['SIGN_PARAM'],
        timeParamName: _authorizationData['TIME_PARAM'],
      );
    }

    if (autoStart) {
      _player.play(url);
    } else {
      _player.setSourceUrl(url);
    }
    _metaData.from(_nowPlayMusic!);
    _metadataEventController.sink.add(_metaData.toMap());
    _setWindowTitle("${_metaData.title}-${_metaData.subTitle}");
    _channel.invokeMethod('traySetToolTip', {
      'toolTip': '${_nowPlayMusic!.name}-${_nowPlayMusic!.singer}',
    });
    _upContextMenu();
    _setSmtcMetadata(_metaData.title, _metaData.subTitle);
  }

  @override
  Future<void> initMethod(
    List<Map> musicList,
    Map<String, dynamic> authorizationData,
  ) async {
    _authorizationData = authorizationData;
    List<Music> musics = musicList.map((item) => Music.fromMap(item)).toList();
    _musicList.clear();
    _musicList.addAll(musics);
    addMusic(musics);
    initPlay();
  }

  @override
  Future<void> playFromId(String id) async {
    playFromMusicId(id);
    initPlay(autoStart: true);
  }

  @override
  Future<void> play() async {
    _player.resume();
  }

  @override
  Future<void> pause() async {
    _player.pause();
  }

  @override
  Future<void> skipToPrevious() async {
    _playbackState.state = MusicStatus.skippingToPrevious;
    _playbackStateController.sink.add(_playbackState.toMap());
    previous(true);
    initPlay(autoStart: true);
  }

  @override
  Future<void> skipToNext() async {
    _playbackState.state = MusicStatus.skippingToNext;
    _playbackStateController.sink.add(_playbackState.toMap());
    next(true);
    initPlay(autoStart: true);
  }

  @override
  Future<void> seekTo(Duration position) async {
    _player.seek(position);
    // Paused playback emits no position events, so refresh the SMTC timeline
    // here to reflect the new position immediately.
    _smtcPositionMs = position.inMilliseconds;
    _updateSmtcTimeline();
  }

  @override
  Future<void> setPlayMode(String mode) async {
    MusicPlayMode musicPlayMode = valueOf(mode.toString().toUpperCase());
    _playMode = musicPlayMode;
    _sharedPreferences.setString(_playModeKey, musicPlayMode.name());
    await _syncSmtcPlayMode(musicPlayMode);
  }

  /// 把 App 的播放模式映射到系统媒体控件的随机/循环按钮。
  Future<void> _syncSmtcPlayMode(MusicPlayMode mode) async {
    bool shuffle = false;
    String repeat = 'none';
    switch (mode) {
      case MusicPlayMode.RANDOMLY:
        shuffle = true;
        break;
      case MusicPlayMode.LOOP:
        repeat = 'list';
        break;
      case MusicPlayMode.SEQUENCE:
        break;
    }
    await _channel.invokeMethod('smtcSetPlayMode', {
      'shuffle': shuffle,
      'repeat': repeat,
    });
  }

  @override
  Future<String> getPlayMode() async {
    return _playMode.name().toLowerCase();
  }

  @override
  Future<List<dynamic>> getPlayList() async {
    return _playList
        .map(
          (e) => {
            'title': e.name ?? '',
            'subTitle': e.singer ?? '',
            'mediaId': e.musicId ?? '',
          },
        )
        .toList();
  }

  @override
  Future<void> delPlayListByMediaId(String mediaId) async {
    if (_nowPlayMusic != null && _nowPlayMusic!.musicId == mediaId) {
      return;
    }
    _playList.removeWhere((element) => mediaId == element.musicId);
    _sharedPreferences.setStringList(
      _playListKey,
      _playList.map((e) => e.musicId!).toList(),
    );
  }

  @override
  Future<void> clearPlayList() async {
    _playList.clear();
    if (_nowPlayMusic != null) {
      _playList.add(_nowPlayMusic!);
      _nowPlayIndex = 0;
      _sharedPreferences.setStringList(
        _playListKey,
        _playList.map((e) => e.musicId!).toList(),
      );
    } else {
      _nowPlayIndex = -1;
      _sharedPreferences.remove(_playListKey);
    }
  }

  @override
  Future<void> setVolume(double value) async {
    await _player.setVolume(value);
    _volumeController.sink.add(_player.volume);
  }

  @override
  Future<void> setCover(Uint8List bytes) async {
    await _channel.invokeMethod('smtcSetCover', {'bytes': bytes});
  }

  void addMusic(List<Music> data) {
    List<String> playListMusicIdList =
        _sharedPreferences.getStringList(_playListKey) ?? [];
    List<Music> playList = [];
    for (String musicId in playListMusicIdList) {
      for (var it in data) {
        if (musicId == it.musicId) {
          playList.add(it);
          break;
        }
      }
    }
    _playList.addAll(playList);

    String? nowPlayMusicId = _sharedPreferences.getString(_nowPlayMusicIdKey);
    if (null != nowPlayMusicId) {
      for (int i = 0; i < _playList.length; i++) {
        if (nowPlayMusicId == _playList[i].musicId) {
          _nowPlayIndex = i;
          _nowPlayMusic = _playList[i];
          break;
        }
      }
    }
    if (-1 == _nowPlayIndex) {
      next(false);
    }
  }

  void playFromMusicId(String musicId) {
    _nowPlayIndex = -1;
    _nowPlayMusic = null;

    for (int i = 0; i < _musicList.length; i++) {
      Music item = _musicList[i];
      if (musicId == item.musicId) {
        _nowPlayMusic = item;
        break;
      }
    }
    if (null == _nowPlayMusic) {
      return;
    }
    int playListIndex = _playList.indexOf(_nowPlayMusic!);
    if (-1 == playListIndex) {
      _playList.add(_nowPlayMusic!);
      _nowPlayIndex = _playList.length - 1;
    } else {
      _nowPlayIndex = playListIndex;
    }
    _sharedPreferences.setStringList(
      _playListKey,
      _playList.map((e) => e.musicId!).toList(),
    );
    _sharedPreferences.setString(_nowPlayMusicIdKey, _nowPlayMusic!.musicId!);
  }

  void previous(bool userTrigger) {
    if (_nowPlayIndex - 1 < 0) {
      // 需要新增
      switch (_playMode.name()) {
        case 'RANDOMLY':
          int randomMusicListIndex = getRandom();
          _nowPlayMusic = _musicList[randomMusicListIndex];
          _playList.remove(_nowPlayMusic);
          _playList.insert(0, _nowPlayMusic!);
          _nowPlayIndex = 0;
          break;
        case 'SEQUENCE':
          int sequenceMusicListIndex = toSequencePrevious();
          _nowPlayMusic = _musicList[sequenceMusicListIndex];
          _playList.remove(_nowPlayMusic);
          _playList.insert(0, _nowPlayMusic!);
          _nowPlayIndex = 0;
          break;
        case 'LOOP':
          if (userTrigger) {
            int sequenceMusicListIndex = toSequencePrevious();
            _nowPlayMusic = _musicList[sequenceMusicListIndex];
            _playList.remove(_nowPlayMusic);
            _playList.insert(0, _nowPlayMusic!);
            _nowPlayIndex = 0;
          }
          break;
      }
    } else if (userTrigger || _playMode.name() != 'LOOP') {
      _nowPlayIndex--;
      _nowPlayMusic = _playList[_nowPlayIndex];
    }
    _sharedPreferences.setStringList(
      _playListKey,
      _playList.map((e) => e.musicId!).toList(),
    );
    _sharedPreferences.setString(_nowPlayMusicIdKey, _nowPlayMusic!.musicId!);
  }

  void next(bool userTrigger) {
    if (_nowPlayIndex + 1 >= _playList.length) {
      // 需要新增
      switch (_playMode.name()) {
        case 'RANDOMLY':
          int randomMusicListIndex = getRandom();
          _nowPlayMusic = _musicList[randomMusicListIndex];
          _playList.remove(_nowPlayMusic);
          _playList.add(_nowPlayMusic!);
          _nowPlayIndex++;
          break;
        case 'SEQUENCE':
          int sequenceMusicListIndex = toSequenceNext();
          _nowPlayMusic = _musicList[sequenceMusicListIndex];
          _playList.remove(_nowPlayMusic);
          _playList.add(_nowPlayMusic!);
          _nowPlayIndex++;
          break;
        case 'LOOP':
          if (userTrigger) {
            int sequenceMusicListIndex = toSequenceNext();
            _nowPlayMusic = _musicList[sequenceMusicListIndex];
            _playList.remove(_nowPlayMusic);
            _playList.add(_nowPlayMusic!);
            _nowPlayIndex++;
          }
          break;
      }
    } else if (userTrigger || _playMode.name() != 'LOOP') {
      _nowPlayIndex++;
      _nowPlayMusic = _playList[_nowPlayIndex];
    }
    _sharedPreferences.setStringList(
      _playListKey,
      _playList.map((e) => e.musicId!).toList(),
    );
    _sharedPreferences.setString(_nowPlayMusicIdKey, _nowPlayMusic!.musicId!);
  }

  int getRandom() {
    List<Music> canPlayList = _musicList
        .where((item) => !_randomSet.contains(item))
        .where((item) => !_playList.contains(item))
        .toList();
    if (canPlayList.isEmpty) {
      _randomSet.clear();
      canPlayList = _musicList;
    }
    Random random = Random();
    int canPlayListIndex = random.nextInt(canPlayList.length);
    Music mediaItem = canPlayList[canPlayListIndex];
    _randomSet.add(mediaItem);
    return _musicList.indexOf(mediaItem);
  }

  int toSequenceNext() {
    if (_nowPlayIndex == -1) {
      return 0;
    }
    Music mediaItem = _playList[_nowPlayIndex];
    int musicListIndex = _musicList.indexOf(mediaItem);
    if (musicListIndex + 1 >= _musicList.length) {
      return 0;
    } else {
      return musicListIndex + 1;
    }
  }

  int toSequencePrevious() {
    if (_nowPlayIndex == -1) {
      return _musicList.length - 1;
    }
    Music mediaItem = _playList[_nowPlayIndex];
    int musicListIndex = _musicList.indexOf(mediaItem);
    if (musicListIndex - 1 < 0) {
      return _musicList.length - 1;
    } else {
      return musicListIndex - 1;
    }
  }
}
