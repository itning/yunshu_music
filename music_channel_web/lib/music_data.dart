import 'dart:html' as html;
import 'dart:math';

import 'package:music_platform_interface/music_model.dart';

class MusicData {
  static const String _nowPlaymusicIdKey = "NOW_PLAY_MEDIA_ID_KEY";
  static const String _playModeKey = "PLAY_MODE";
  static const String _playListKey = "PLAY_LIST";

  static MusicData? _instance;

  static MusicData get() {
    _instance ??= MusicData();
    return _instance!;
  }

  final List<Music> _musicList = [];
  final List<Music> _playList = [];
  final Set<Music> _randomSet = {};
  late int _nowPlayIndex;
  Music? _nowPlayMusic;
  late MusicPlayMode _playMode;
  final html.Storage _storage = html.window.localStorage;

  MusicData() {
    _nowPlayIndex = -1;
    String mode = _storage[_playModeKey] ?? 'SEQUENCE';
    _playMode = valueOf(mode);
  }

  Music? get nowPlayMusic => _nowPlayMusic;

  List<Music> get playList => _playList;

  MusicPlayMode get playMode => _playMode;

  set playMode(MusicPlayMode value) {
    _playMode = value;
    _storage[_playModeKey] = value.name();
  }

  void addMusic(List<Music> data) {
    _musicList.addAll(data);
    String playListString = _storage[_playListKey] ?? '';
    List<String> playListMusicIdList = playListString.split("@").toList();
    List<Music> playList = [];
    for (String musicId in playListMusicIdList) {
      for (var it in _musicList) {
        if (musicId == it.musicId) {
          playList.add(it);
          break;
        }
      }
    }
    _playList.addAll(playList);

    String? nowPlaymusicId = _storage[_nowPlaymusicIdKey];
    if (null != nowPlaymusicId) {
      for (int i = 0; i < _playList.length; i++) {
        if (nowPlaymusicId == _playList[i].musicId) {
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

  void delPlayListByMediaId(String mediaId) {
    _playList.removeWhere((element) => mediaId == element.musicId);

    String playListString = _playList.map((e) => e.musicId).join('@');
    _storage[_playListKey] = playListString;
  }

  void clearPlayList() {
    _playList.clear();
    _nowPlayIndex = -1;
    _storage[_playListKey] = '';
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
    String playListString = _playList.map((e) => e.musicId).join('@');
    _storage[_playListKey] = playListString;
    _storage[_nowPlaymusicIdKey] = _nowPlayMusic!.musicId!;
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
    String playListString = _playList.map((e) => e.musicId).join('@');
    _storage[_playListKey] = playListString;
    _storage[_nowPlaymusicIdKey] = _nowPlayMusic!.musicId!;
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
          _playList.remove(nowPlayMusic);
          _playList.add(nowPlayMusic!);
          _nowPlayIndex++;
          break;
        case 'LOOP':
          if (userTrigger) {
            int sequenceMusicListIndex = toSequenceNext();
            _nowPlayMusic = _musicList[sequenceMusicListIndex];
            _playList.remove(nowPlayMusic);
            _playList.add(nowPlayMusic!);
            _nowPlayIndex++;
          }
          break;
      }
    } else if (userTrigger || _playMode.name() != 'LOOP') {
      _nowPlayIndex++;
      _nowPlayMusic = _playList[_nowPlayIndex];
    }
    String playListString = _playList.map((e) => e.musicId).join('@');
    _storage[_playListKey] = playListString;
    _storage[_nowPlaymusicIdKey] = _nowPlayMusic!.musicId!;
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
