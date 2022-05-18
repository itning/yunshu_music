import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dart_vlc/dart_vlc.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:music_platform_interface/music_model.dart';
import 'package:music_platform_interface/music_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_tray/system_tray.dart' as tray;
import 'package:window_manager/window_manager.dart';
import 'package:window_size/window_size.dart';

class MusicChannelMacOS extends MusicPlatform {
  static void registerWith() {
    MusicPlatform.instance = MusicChannelMacOS();
  }

  static const MethodChannel _channel = MethodChannel('music_channel_macos');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static const String _nowPlaymusicIdKey = "NOW_PLAY_MEDIA_ID_KEY";
  static const String _playModeKey = "PLAY_MODE";
  static const String _playListKey = "PLAY_LIST";

  /// 播放实例
  late Player _player;

  /// 播放元数据信息：歌曲信息，时长等。
  late StreamController<dynamic> _metadataEventController;

  /// 播放状态信息：是否播放，播放进度，缓冲进度
  late StreamController<dynamic> _playbackStateController;

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
  final MetaData _metaData = MetaData();

  /// 播放状态载体
  final PlaybackState _playbackState = PlaybackState();

  /// 随即过的音乐信息
  final Set<Music> _randomSet = {};

  /// 正在播放的音乐信息
  Music? _nowPlayMusic;

  bool _first = true;

  late tray.SystemTray _systemTray;

  bool _isPlayNow = false;

  late List<tray.MenuItemBase> _menus;

  @override
  Future<void> init(
      StreamController<dynamic> metadataEventController,
      StreamController<dynamic> playbackStateController,
      StreamController<double> volumeController) async {
    setWindowTitle("云舒音乐");
    setWindowMinSize(const Size(450, 900));

    this._metadataEventController = metadataEventController;
    this._playbackStateController = playbackStateController;
    _sharedPreferences = await SharedPreferences.getInstance();

    _nowPlayIndex = -1;
    _playMode =
        valueOf(_sharedPreferences.getString(_playModeKey) ?? 'SEQUENCE');
    await windowManager.ensureInitialized();

    DartVLC.initialize();
    _player = Player(id: 69420);
    _systemTray = tray.SystemTray();

    _menus = [
      tray.MenuItem(label: '云舒音乐', onClicked: () => windowManager.show()),
      tray.MenuSeparator(),
      tray.MenuItem(label: '上一曲', onClicked: () => skipToPrevious()),
      tray.MenuItem(label: '下一曲', onClicked: () => skipToNext()),
      tray.MenuSeparator(),
      tray.MenuItem(label: '退出', onClicked: () => exit(0)),
    ];

    _player.positionStream.listen((event) {
      int position = event.position?.inMilliseconds ?? 0;
      int duration = event.duration?.inMilliseconds ?? 0;
      _playbackState.position = position;
      _metaData.duration(duration);

      playbackStateController.sink.add(_playbackState.toMap());
      metadataEventController.sink.add(_metaData.toMap());
    });

    _player.playbackStream.listen((event) {
      if (_first || _playbackState.state != 8 || event.isPlaying) {
        if (_first) {
          _first = false;
        }
        _playbackState.state = event.isPlaying ? 3 : 2;
        playbackStateController.sink.add(_playbackState.toMap());
        _isPlayNow = event.isPlaying;
        _upContextMenu();
      }
      if (event.isCompleted) {
        _playbackState.state = 0;
        playbackStateController.sink.add(_playbackState.toMap());
        next(false);
        initPlay(autoStart: true);
      }
    });

    _player.generalStream.listen((event) {
      volumeController.sink.add(event.volume);
    });

    _playbackState.state = 0;

    await _systemTray.initSystemTray(
      title: "云舒音乐",
      iconPath: "asserts/icon/app_icon.ico",
      toolTip: "云舒音乐",
    );

    await _systemTray.setContextMenu(_menus);
    _systemTray.registerSystemTrayEventHandler((eventName) {
      if (eventName == "rightMouseUp") {
        _systemTray.popUpContextMenu();
      } else if (eventName == "leftMouseDown") {
        windowManager.isVisible().then(
            (visible) => visible ? windowManager.hide() : windowManager.show());
      }
    });
  }

  void _upContextMenu() {
    if (_menus.length != 6) {
      _menus.removeAt(4);
    }
    _menus.insert(
        4,
        tray.MenuItem(
            label: _isPlayNow ? '暂停' : '播放',
            onClicked: () {
              _isPlayNow ? pause() : play();
            }));
    _systemTray.setContextMenu(_menus);
  }

  void initPlay({bool autoStart = false}) {
    if (_nowPlayMusic == null) {
      return;
    }
    if (_nowPlayMusic!.musicUri == null) {
      return;
    }
    _playbackState.state = 8;
    _playbackStateController.sink.add(_playbackState.toMap());
    _player.open(Media.network(_nowPlayMusic!.musicUri!), autoStart: autoStart);
    _metaData.from(_nowPlayMusic!);
    _metadataEventController.sink.add(_metaData.toMap());
    _systemTray.setTitle('${_nowPlayMusic!.name}-${_nowPlayMusic!.singer}');
  }

  @override
  Future<void> initMethod(List<Map> musicList) async {
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
    _player.play();
  }

  @override
  Future<void> pause() async {
    _player.pause();
  }

  @override
  Future<void> skipToPrevious() async {
    _playbackState.state = 9;
    _playbackStateController.sink.add(_playbackState.toMap());
    previous(true);
    initPlay(autoStart: true);
  }

  @override
  Future<void> skipToNext() async {
    _playbackState.state = 10;
    _playbackStateController.sink.add(_playbackState.toMap());
    next(true);
    initPlay(autoStart: true);
  }

  @override
  Future<void> seekTo(Duration position) async {
    _player.seek(position);
  }

  @override
  Future<void> setPlayMode(String mode) async {
    MusicPlayMode musicPlayMode = valueOf(mode.toString().toUpperCase());
    _playMode = musicPlayMode;
    _sharedPreferences.setString(_playModeKey, musicPlayMode.name());
  }

  @override
  Future<String> getPlayMode() async {
    return _playMode.name().toLowerCase();
  }

  @override
  Future<List<dynamic>> getPlayList() async {
    return _playList
        .map((e) => {
              'title': e.name ?? '',
              'subTitle': e.singer ?? '',
              'mediaId': e.musicId ?? ''
            })
        .toList();
  }

  @override
  Future<void> delPlayListByMediaId(String mediaId) async {
    _playList.removeWhere((element) => mediaId == element.musicId);
    _sharedPreferences.setStringList(
        _playListKey, _playList.map((e) => e.musicId!).toList());
  }

  @override
  Future<void> clearPlayList() async {
    _playList.clear();
    _nowPlayIndex = -1;
    _sharedPreferences.remove(_playListKey);
  }

  @override
  Future<void> setVolume(double value) async {
    _player.setVolume(value);
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

    String? nowPlayMusicId = _sharedPreferences.getString(_nowPlaymusicIdKey);
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
        _playListKey, _playList.map((e) => e.musicId!).toList());
    _sharedPreferences.setString(_nowPlaymusicIdKey, _nowPlayMusic!.musicId!);
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
        _playListKey, _playList.map((e) => e.musicId!).toList());
    _sharedPreferences.setString(_nowPlaymusicIdKey, _nowPlayMusic!.musicId!);
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
        _playListKey, _playList.map((e) => e.musicId!).toList());
    _sharedPreferences.setString(_nowPlaymusicIdKey, _nowPlayMusic!.musicId!);
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

class MetaData {
  final Map<String, dynamic> _map = {
    'duration': 0,
    'title': '',
    'subTitle': '',
    'mediaId': '',
    'musicUri': '',
    'lyricUri': ''
  };

  void from(Music music) {
    _map['title'] = music.name;
    _map['subTitle'] = music.singer;
    _map['mediaId'] = music.musicId;
    _map['coverUri'] = music.coverUri;
    _map['musicUri'] = music.musicUri;
    _map['lyricUri'] = music.lyricUri;
  }

  void duration(int duration) {
    _map['duration'] = duration;
  }

  int get durations => _map['duration'];

  Map<String, dynamic> toMap() {
    return _map;
  }
}

class PlaybackState {
  final Map<String, dynamic> _map = {
    'bufferedPosition': 0,
    'position': 0,
    'state': -1
  };
  int bufferedPosition = 0;
  int position = 0;
  int state = -1;

  Map<String, dynamic> toMap() {
    _map['bufferedPosition'] = bufferedPosition;
    _map['position'] = position;
    _map['state'] = state;
    return _map;
  }
}

enum MusicPlayMode { SEQUENCE, RANDOMLY, LOOP }

extension MusicPlayModeExtension on MusicPlayMode {
  String name() {
    switch (index) {
      case 0:
        return 'SEQUENCE';
      case 1:
        return 'RANDOMLY';
      case 2:
        return 'LOOP';
      default:
        return 'SEQUENCE';
    }
  }
}

MusicPlayMode valueOf(String name) {
  switch (name) {
    case 'SEQUENCE':
      return MusicPlayMode.SEQUENCE;
    case 'RANDOMLY':
      return MusicPlayMode.RANDOMLY;
    case 'LOOP':
      return MusicPlayMode.LOOP;
    default:
      return MusicPlayMode.SEQUENCE;
  }
}
