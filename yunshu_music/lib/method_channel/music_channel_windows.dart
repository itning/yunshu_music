import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:dart_vlc/dart_vlc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_size/window_size.dart';
import 'package:yunshu_music/method_channel/music_channel.dart';
import 'package:yunshu_music/net/model/music_entity.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/util/common_utils.dart';

/// Windows端
class MusicChannelWindows extends MusicChannel {
  static const String _nowPlaymusicIdKey = "NOW_PLAY_MEDIA_ID_KEY";
  static const String _playModeKey = "PLAY_MODE";
  static const String _playListKey = "PLAY_LIST";

  /// 播放实例
  late Player player;

  /// 播放元数据信息：歌曲信息，时长等。
  late StreamController<dynamic> metadataEventController;

  /// 播放状态信息：是否播放，播放进度，缓冲进度
  late StreamController<dynamic> playbackStateController;

  /// 数据落地
  late SharedPreferences sharedPreferences;

  /// 播放列表指针
  late int _nowPlayIndex;

  /// 播放模式
  late MusicPlayMode _playMode;

  /// 播放列表
  final List<MusicDataContent> _playList = [];

  /// 元数据载体
  final MetaData _metaData = MetaData();

  /// 播放状态载体
  final PlaybackState _playbackState = PlaybackState();

  /// 随即过的音乐信息
  final Set<MusicDataContent> _randomSet = {};

  /// 正在播放的音乐信息
  MusicDataContent? _nowPlayMusic;

  bool first = true;

  @override
  Future<void> init(SharedPreferences sharedPreferences) async {
    if (!Platform.isWindows) {
      LogHelper().error('非windows平台调用');
      return;
    }

    setWindowTitle("云舒音乐");
    setWindowMinSize(const Size(400, 800));
    setWindowMaxSize(const Size(400, 800));

    this.sharedPreferences = sharedPreferences;
    _nowPlayIndex = -1;
    _playMode =
        valueOf(sharedPreferences.getString(_playModeKey) ?? 'SEQUENCE');

    LogHelper().debug('初始化DartVLC');
    DartVLC.initialize();
    player = Player(id: 69420);

    playbackStateController = StreamController<dynamic>();
    playbackStateEvent = playbackStateController.stream;
    metadataEventController = StreamController<dynamic>();
    metadataEvent = metadataEventController.stream;

    player.positionStream.listen((event) {
      _playbackState.position = event.position?.inMilliseconds ?? 0;
      _metaData.duration(event.duration?.inMilliseconds ?? 0);

      playbackStateController.sink.add(_playbackState.toMap());
      metadataEventController.sink.add(_metaData.toMap());
    });

    player.playbackStream.listen((event) {
      LogHelper().debug(
          'isPlaying ${event.isPlaying} isSeekable ${event.isSeekable} isCompleted ${event.isCompleted}');
      if (first || _playbackState.state != 8 || event.isPlaying) {
        if (first) {
          first = false;
        }
        _playbackState.state = event.isPlaying ? 3 : 2;
        playbackStateController.sink.add(_playbackState.toMap());
      }
      if (event.isCompleted) {
        _playbackState.state = 0;
        playbackStateController.sink.add(_playbackState.toMap());
        next(false);
        initPlay(autoStart: true);
      }
    });

    _playbackState.state = 0;
  }

  void initPlay({bool autoStart = false}) {
    if (_nowPlayMusic == null) {
      return;
    }
    if (_nowPlayMusic!.musicUri == null) {
      return;
    }
    _playbackState.state = 8;
    playbackStateController.sink.add(_playbackState.toMap());
    player.open(Media.network(_nowPlayMusic!.musicUri!), autoStart: autoStart);
    _metaData.from(_nowPlayMusic!);
    metadataEventController.sink.add(_metaData.toMap());
  }

  @override
  Future<void> initMethod() async {
    addMusic(MusicDataModel.get().musicList);
    initPlay();
  }

  @override
  Future<void> playFromId(String id) async {
    playFromMusicId(id);
    initPlay(autoStart: true);
  }

  @override
  Future<void> play() async {
    player.play();
  }

  @override
  Future<void> pause() async {
    player.pause();
  }

  @override
  Future<void> skipToPrevious() async {
    _playbackState.state = 9;
    playbackStateController.sink.add(_playbackState.toMap());
    previous(true);
    initPlay(autoStart: true);
  }

  @override
  Future<void> skipToNext() async {
    _playbackState.state = 10;
    playbackStateController.sink.add(_playbackState.toMap());
    next(true);
    initPlay(autoStart: true);
  }

  @override
  Future<void> seekTo(Duration position) async {
    player.seek(position);
  }

  @override
  Future<void> setPlayMode(String mode) async {
    MusicPlayMode musicPlayMode = valueOf(mode.toString().toUpperCase());
    _playMode = musicPlayMode;
    sharedPreferences.setString(_playModeKey, musicPlayMode.name());
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
    sharedPreferences.setStringList(
        _playListKey, _playList.map((e) => e.musicId!).toList());
  }

  void addMusic(List<MusicDataContent> data) {
    List<String> playListMusicIdList =
        sharedPreferences.getStringList(_playListKey) ?? [];
    List<MusicDataContent> playList = [];
    for (String musicId in playListMusicIdList) {
      for (var it in data) {
        if (musicId == it.musicId) {
          playList.add(it);
          break;
        }
      }
    }
    _playList.addAll(playList);

    String? nowPlayMusicId = sharedPreferences.getString(_nowPlaymusicIdKey);
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

    for (int i = 0; i < MusicDataModel.get().musicList.length; i++) {
      MusicDataContent item = MusicDataModel.get().musicList[i];
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
    sharedPreferences.setStringList(
        _playListKey, _playList.map((e) => e.musicId!).toList());
    sharedPreferences.setString(_nowPlaymusicIdKey, _nowPlayMusic!.musicId!);
  }

  void previous(bool userTrigger) {
    if (_nowPlayIndex - 1 < 0) {
      // 需要新增
      switch (_playMode.name()) {
        case 'RANDOMLY':
          int randomMusicListIndex = getRandom();
          _nowPlayMusic = MusicDataModel.get().musicList[randomMusicListIndex];
          _playList.remove(_nowPlayMusic);
          _playList.insert(0, _nowPlayMusic!);
          _nowPlayIndex = 0;
          break;
        case 'SEQUENCE':
          int sequenceMusicListIndex = toSequencePrevious();
          _nowPlayMusic =
              MusicDataModel.get().musicList[sequenceMusicListIndex];
          _playList.remove(_nowPlayMusic);
          _playList.insert(0, _nowPlayMusic!);
          _nowPlayIndex = 0;
          break;
        case 'LOOP':
          if (userTrigger) {
            int sequenceMusicListIndex = toSequencePrevious();
            _nowPlayMusic =
                MusicDataModel.get().musicList[sequenceMusicListIndex];
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
    sharedPreferences.setStringList(
        _playListKey, _playList.map((e) => e.musicId!).toList());
    sharedPreferences.setString(_nowPlaymusicIdKey, _nowPlayMusic!.musicId!);
  }

  void next(bool userTrigger) {
    if (_nowPlayIndex + 1 >= _playList.length) {
      // 需要新增
      switch (_playMode.name()) {
        case 'RANDOMLY':
          int randomMusicListIndex = getRandom();
          _nowPlayMusic = MusicDataModel.get().musicList[randomMusicListIndex];
          _playList.remove(_nowPlayMusic);
          _playList.add(_nowPlayMusic!);
          _nowPlayIndex++;
          break;
        case 'SEQUENCE':
          int sequenceMusicListIndex = toSequenceNext();
          _nowPlayMusic =
              MusicDataModel.get().musicList[sequenceMusicListIndex];
          _playList.remove(_nowPlayMusic);
          _playList.add(_nowPlayMusic!);
          _nowPlayIndex++;
          break;
        case 'LOOP':
          if (userTrigger) {
            int sequenceMusicListIndex = toSequenceNext();
            _nowPlayMusic =
                MusicDataModel.get().musicList[sequenceMusicListIndex];
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
    sharedPreferences.setStringList(
        _playListKey, _playList.map((e) => e.musicId!).toList());
    sharedPreferences.setString(_nowPlaymusicIdKey, _nowPlayMusic!.musicId!);
  }

  int getRandom() {
    List<MusicDataContent> canPlayList = MusicDataModel.get()
        .musicList
        .where((item) => !_randomSet.contains(item))
        .where((item) => !_playList.contains(item))
        .toList();
    if (canPlayList.isEmpty) {
      _randomSet.clear();
      canPlayList = MusicDataModel.get().musicList;
    }
    Random random = Random();
    int canPlayListIndex = random.nextInt(canPlayList.length);
    MusicDataContent mediaItem = canPlayList[canPlayListIndex];
    _randomSet.add(mediaItem);
    return MusicDataModel.get().musicList.indexOf(mediaItem);
  }

  int toSequenceNext() {
    if (_nowPlayIndex == -1) {
      return 0;
    }
    MusicDataContent mediaItem = _playList[_nowPlayIndex];
    int musicListIndex = MusicDataModel.get().musicList.indexOf(mediaItem);
    if (musicListIndex + 1 >= MusicDataModel.get().musicList.length) {
      return 0;
    } else {
      return musicListIndex + 1;
    }
  }

  int toSequencePrevious() {
    if (_nowPlayIndex == -1) {
      return MusicDataModel.get().musicList.length - 1;
    }
    MusicDataContent mediaItem = _playList[_nowPlayIndex];
    int musicListIndex = MusicDataModel.get().musicList.indexOf(mediaItem);
    if (musicListIndex - 1 < 0) {
      return MusicDataModel.get().musicList.length - 1;
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

  void from(MusicDataContent music) {
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
