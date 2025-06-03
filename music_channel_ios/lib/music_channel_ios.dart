import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:music_platform_interface/music_model.dart';
import 'package:music_platform_interface/music_platform_interface.dart';
import 'package:music_platform_interface/music_play_mode.dart';
import 'package:music_platform_interface/music_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MusicChannelIos extends MusicPlatform {
  static void registerWith() {
    MusicPlatform.instance = MusicChannelIos();
  }

  static const MethodChannel _channel = MethodChannel('music_channel_ios');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static const String _nowPlayMusicIdKey = "NOW_PLAY_MEDIA_ID_KEY";
  static const String _playModeKey = "PLAY_MODE";
  static const String _playListKey = "PLAY_LIST";

  /// 播放实例
  late AudioPlayer _player;

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

  @override
  Future<void> init(
    StreamController<dynamic> metadataEventController,
    StreamController<dynamic> playbackStateController,
    StreamController<double> volumeController,
  ) async {
    _metadataEventController = metadataEventController;
    _playbackStateController = playbackStateController;
    _volumeController = volumeController;
    _sharedPreferences = await SharedPreferences.getInstance();

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'playButtonTapped':
          await play();
        case 'pauseButtonTapped':
          await pause();
        case 'nextButtonTapped':
          await skipToNext();
        case 'previousButtonTapped':
          await skipToPrevious();
        case "seekTo":
          await seekTo(Duration(seconds: call.arguments["position"]));
        case 'togglePlayPause':
          PlayerState.playing == _player.state ? await pause() : await play();
        case 'headphonesUnplugged':
        case 'audioInterruptionBegan':
          if (PlayerState.playing == _player.state) {
            await pause();
          }
        case 'audioInterruptionEnded':
        case 'audioInterruptionShouldResume':
          break;
      }
    });

    _channel.invokeMethod("init");

    _nowPlayIndex = -1;
    _playMode = valueOf(
      _sharedPreferences.getString(_playModeKey) ?? 'SEQUENCE',
    );

    _player = AudioPlayer(playerId: "69420");
    _player.setReleaseMode(ReleaseMode.stop);
    _player.setPlayerMode(PlayerMode.mediaPlayer);

    _player.onPositionChanged.listen((Duration event) {
      int position = event.inMilliseconds;
      _playbackState.position = position;
      playbackStateController.sink.add(_playbackState.toMap());
      _channel.invokeMethod("setLockScreenDisplayTime", {
        "duration": Duration(milliseconds: _metaData.duration).inSeconds,
        "time": event.inSeconds,
      });
    });

    _player.onPlayerStateChanged.listen((PlayerState event) {
      if (PlayerState.completed == event) {
        return;
      }
      bool playing = PlayerState.playing == event;
      _playbackState.state = playing ? MusicStatus.playing : MusicStatus.paused;
      playbackStateController.sink.add(_playbackState.toMap());
    });

    _player.eventStream.listen((AudioEvent event) {
      switch (event.eventType) {
        case AudioEventType.log:
          break;
        case AudioEventType.duration:
          if (null != event.duration) {
            int duration = event.duration!.inMilliseconds;
            _metaData.duration = duration;
            metadataEventController.sink.add(_metaData.toMap());
            _channel.invokeMethod("setLockScreenDisplay", {
              "name": _nowPlayMusic!.name,
              "singer": _nowPlayMusic!.singer,
              "coverUri": _nowPlayMusic!.coverUri,
              "duration": event.duration!.inSeconds,
            });
          }
        case AudioEventType.seekComplete:
          break;
        case AudioEventType.complete:
          _playbackState.state = MusicStatus.none;
          playbackStateController.sink.add(_playbackState.toMap());
          next(false);
          initPlay(autoStart: true);
        case AudioEventType.prepared:
          if (event.isPrepared ?? false) {
            _playbackState.state = MusicStatus.paused;
            _playbackStateController.sink.add(_playbackState.toMap());
            _channel.invokeMethod("changeToPaused");
          }
      }
    });

    _playbackState.state = MusicStatus.none;
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
    _channel.invokeMethod("setLockScreenDisplay", {
      "name": _nowPlayMusic!.name,
      "singer": _nowPlayMusic!.singer,
      "coverUri": _nowPlayMusic!.coverUri,
      "duration": 0,
    });
    if (autoStart) {
      _player.play(UrlSource(_nowPlayMusic!.musicUri!));
    } else {
      _player.setSourceUrl(_nowPlayMusic!.musicUri!);
    }
    _metaData.from(_nowPlayMusic!);
    _metadataEventController.sink.add(_metaData.toMap());
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
