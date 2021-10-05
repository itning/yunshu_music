import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_rest_template/response_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yunshu_music/component/lyric/lyric.dart';
import 'package:yunshu_music/component/lyric/lyric_util.dart';
import 'package:yunshu_music/net/http_helper.dart';
import 'package:yunshu_music/net/model/music_entity.dart';
import 'package:yunshu_music/net/model/music_meta_info_entity.dart';
import 'package:yunshu_music/provider/cache_model.dart';
import 'package:yunshu_music/provider/play_status_model.dart';
import 'package:yunshu_music/util/common_utils.dart';

/// 音乐数据模型
class MusicDataModel extends ChangeNotifier {
  static const String _playModeKey = "PLAY_MODE";
  static const String _nowPlayIndexKey = "NOW_PLAY_INDEX";

  static MusicDataModel? _instance;

  static MusicDataModel get() {
    _instance ??= MusicDataModel();
    return _instance!;
  }

  bool _isInit = false;

  late SharedPreferences _sharedPreferences;

  /// 正在播放的列表
  final List<MusicDataContent> _playList = [];

  /// 所有音乐列表
  List<MusicDataContent> _musicList = [];

  /// 随机过的音乐集合
  final Set<MusicDataContent> _randomPlayedSet = {};

  /// 正在播放的音乐在_playList里的索引
  int _nowPlayIndex = 0;

  /// 正在播放的音乐在_musicList里的索引
  int _nowMusicIndex = 0;

  /// 当前歌曲的歌词信息
  List<Lyric>? _lyricList;

  /// 音乐封面
  String? _coverBase64;

  /// 播放模式
  String _playMode = 'sequence';

  /// 获取音乐列表
  List<MusicDataContent> get musicList => _musicList;

  /// 获取当前歌词信息
  List<Lyric>? get lyricList => _lyricList;

  /// 获取音乐封面
  String? get coverBase64 => _coverBase64;

  /// 获取正在播放的音乐在_musicList里的索引
  int get nowMusicIndex => _nowMusicIndex;

  /// 获取播放模式
  String get playMode => _playMode;

  /// 刷新音乐列表
  Future<String?> refreshMusicList({bool needInit = false}) async {
    if (needInit) {
      List<MusicDataContent> list = await CacheModel.get().getMusicList();
      if (list.isNotEmpty) {
        _musicList = list;
        await _initPlay();
        notifyListeners();
        return null;
      }
    }
    ResponseEntity<MusicEntity> responseEntity =
        await HttpHelper.get().getMusic();
    if (responseEntity.body == null) {
      return '服务器<${responseEntity.status.value}> BODY NULL';
    }
    if (responseEntity.body!.code != 200 || responseEntity.body!.data == null) {
      return responseEntity.body!.msg ?? '服务器错误';
    }
    if (responseEntity.body!.data!.content == null) {
      return null;
    }
    _musicList = responseEntity.body!.data!.content!;
    CacheModel.get().cacheMusicList(_musicList);
    if (needInit) {
      await _initPlay();
    }
    notifyListeners();
  }

  Future<void> init(SharedPreferences sharedPreferences) async {
    _sharedPreferences = sharedPreferences;
    _playMode = sharedPreferences.getString(_playModeKey) ?? 'sequence';
    _nowPlayIndex = sharedPreferences.getInt(_nowPlayIndexKey) ?? 0;
  }

  Future<void> nextPlayMode() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    switch (_playMode) {
      case 'sequence':
        _playMode = 'randomly';
        sharedPreferences.setString(_playModeKey, _playMode);
        notifyListeners();
        break;
      case 'randomly':
        _playMode = 'loop';
        sharedPreferences.setString(_playModeKey, _playMode);
        notifyListeners();
        break;
      case 'loop':
        _playMode = 'sequence';
        sharedPreferences.setString(_playModeKey, _playMode);
        notifyListeners();
        break;
      default:
        _playMode = 'sequence';
        sharedPreferences.setString(_playModeKey, _playMode);
        notifyListeners();
        break;
    }
  }

  /// 搜索音乐和歌手
  List<MusicDataContent> search(String keyword) {
    if (keyword.trim() == '') {
      return [];
    }
    String lowerCaseKeyword = keyword.toLowerCase();
    List<MusicDataContent> searchResultList = _musicList.where((musicItem) {
      bool containsName = false;
      bool containsSinger = false;
      if (musicItem.name != null) {
        containsName =
            musicItem.name!.toLowerCase().contains(lowerCaseKeyword);
      }
      if (musicItem.singer != null) {
        containsSinger =
            musicItem.singer!.toLowerCase().contains(lowerCaseKeyword);
      }
      return containsName || containsSinger;
    }).toList();
    return searchResultList;
  }

  /// 获取现在正在播放的音乐信息
  MusicDataContent? getNowPlayMusic() {
    if (_playList.isEmpty) {
      return null;
    } else {
      return _playList[_nowPlayIndex];
    }
  }

  /// 设置现在正在播放的音乐信息
  Future<void> setNowPlayMusicUseMusicId(String? musicId) async {
    if (null == musicId) {
      return;
    }
    int index = _musicList.indexWhere((element) => musicId == element.musicId);
    if (-1 == index) {
      return;
    }
    await setNowPlayMusic(index);
  }

  /// 设置现在正在播放的音乐信息
  Future<void> setNowPlayMusic(int index) async {
    if (index > _musicList.length - 1) {
      return;
    }
    if (_nowMusicIndex == index) {
      if (!PlayStatusModel.get().isPlayNow) {
        await PlayStatusModel.get().setPlay(true);
        notifyListeners();
      }
      return;
    }
    MusicDataContent music = _musicList[index];
    // 检查播放列表有没有这首歌，有的话直接将播放
    for (int i = 0; i < _playList.length; i++) {
      if (music.musicId == _playList[i].musicId) {
        _nowPlayIndex = i;
        _sharedPreferences.setInt(_nowPlayIndexKey, _nowPlayIndex);
        await doPlay();
        return;
      }
    }
    _playList.add(music);
    CacheModel.get().cachePlayListAddOne(music);
    _nowPlayIndex = _playList.length - 1;
    _sharedPreferences.setInt(_nowPlayIndexKey, _nowPlayIndex);
    await doPlay();
  }

  /// 初始化播放信息，这时候没播放但是应该让用户知道播放哪首歌
  Future<void> _initPlay() async {
    if (_isInit) {
      return;
    }
    _isInit = true;
    List<MusicDataContent> playListFromCache =
        await CacheModel.get().getPlayList();
    if (playListFromCache.isNotEmpty &&
        playListFromCache.length > _nowPlayIndex) {
      // 移除在所有音乐列表中不存在的历史播放歌曲，初始化完成后调用
      MusicDataContent music = playListFromCache[_nowPlayIndex];
      Set<String> musicIdSet = _musicList
          .map((element) => element.musicId ?? '')
          .where((element) => element != '')
          .toSet();
      playListFromCache
          .removeWhere((element) => !musicIdSet.contains(element.musicId));
      if (playListFromCache.isNotEmpty) {
        if (!playListFromCache.contains(music)) {
          _nowPlayIndex = 0;
          _sharedPreferences.setInt(_nowPlayIndexKey, _nowPlayIndex);
          music = playListFromCache[_nowPlayIndex];
        }
        _playList.clear();
        _playList.addAll(playListFromCache);
        if (null != music.lyricId) {
          await _initLyric(music.lyricId!);
        }
        if (null != music.musicId) {
          _nowMusicIndex = _musicList
              .indexWhere((element) => element.musicId == music.musicId);
          await _initCover(music.musicId!);
          await PlayStatusModel.get()
              .setSource(HttpHelper.get().getMusicUrl(music.musicId!));
        }
        return;
      }
    }

    _nowPlayIndex = 0;
    _sharedPreferences.setInt(_nowPlayIndexKey, _nowPlayIndex);
    MusicDataContent music = _musicList[_nowPlayIndex];
    _playList.add(music);
    CacheModel.get().cachePlayListAddOne(music);
    if (null != music.lyricId) {
      await _initLyric(music.lyricId!);
    }
    if (null != music.musicId) {
      _nowMusicIndex =
          _musicList.indexWhere((element) => element.musicId == music.musicId);
      await _initCover(music.musicId!);
      await PlayStatusModel.get()
          .setSource(HttpHelper.get().getMusicUrl(music.musicId!));
    }
  }

  Future<void> doPlay() async {
    await PlayStatusModel.get().setPlay(false);
    await PlayStatusModel.get().stopPlay();
    if (_playList.isEmpty) {
      return;
    }
    if (_playList.length < _nowPlayIndex + 1) {
      return;
    }
    MusicDataContent music = _playList[_nowPlayIndex];
    if (null != music.musicId) {
      _nowMusicIndex =
          _musicList.indexWhere((element) => element.musicId == music.musicId);
      await _initCover(music.musicId!);
      if (null != music.lyricId) {
        await _initLyric(music.lyricId!);
      }
      await PlayStatusModel.get()
          .setSource(HttpHelper.get().getMusicUrl(music.musicId!));
      await PlayStatusModel.get().setPlay(true);
      notifyListeners();
    }
  }

  /// 上一曲
  Future<void> toPrevious() async {
    if (_musicList.isEmpty) {
      return;
    }
    MusicDataContent? previousMusic = _getPreviousMusic();
    if (null == previousMusic) {
      return;
    }
    await doPlay();
  }

  /// 下一曲
  Future<void> toNext() async {
    if (_musicList.isEmpty) {
      return;
    }
    MusicDataContent? nextMusic = _getNextMusic();
    if (null == nextMusic) {
      LogHelper.get().warn('下一曲为空');
      return;
    }
    await doPlay();
  }

  Future<void> _initLyric(String lyricId) async {
    String? lyric = await CacheModel.get().getLyric(lyricId);
    if (lyric == null) {
      lyric = await HttpHelper.get().getLyric(lyricId);
      CacheModel.get().cacheLyric(lyricId, lyric);
    }
    List<Lyric>? list = LyricUtil.formatLyric(lyric);
    _lyricList = list;
    notifyListeners();
  }

  Future<void> _initCover(String musicId) async {
    String? coverFromCache = await CacheModel.get().getCover(musicId);
    if (null != coverFromCache) {
      _coverBase64 = coverFromCache;
      notifyListeners();
      return;
    }
    ResponseEntity<MusicMetaInfoEntity> responseEntity =
        await HttpHelper.get().getMetaInfo(musicId);
    if (responseEntity.status.value != 200) {
      _coverBase64 = null;
      return;
    }

    if (responseEntity.body == null || responseEntity.body!.data == null) {
      _coverBase64 = null;
      return;
    }

    if (responseEntity.body!.data!.coverPictures == null) {
      _coverBase64 = null;
      return;
    }

    if (responseEntity.body!.data!.coverPictures!.isEmpty) {
      _coverBase64 = null;
      return;
    }

    MusicMetaInfoDataCoverPictures pictures =
        responseEntity.body!.data!.coverPictures![0];
    _coverBase64 = pictures.base64;
    CacheModel.get().cacheCover(musicId, _coverBase64);
    notifyListeners();
  }

  /// 上一曲
  MusicDataContent? _getPreviousMusic() {
    // 如果播放列表为空则获取一首歌曲
    if (_playList.isEmpty) {
      MusicDataContent? music = _getSongs();
      if (null == music) {
        return null;
      }
      _playList.insert(0, music);
      _nowPlayIndex = 0;
      _sharedPreferences.setInt(_nowPlayIndexKey, _nowPlayIndex);
      CacheModel.get().cachePlayList(_playList);
      return music;
    } else {
      // 播放列表不是空的，尝试索引位置-1
      if (_nowPlayIndex - 1 < 0) {
        // 说明是上一首歌不存在了，获取一首
        MusicDataContent? music = _getSongs();
        if (null == music) {
          return null;
        }
        _playList.insert(0, music);
        _nowPlayIndex = 0;
        _sharedPreferences.setInt(_nowPlayIndexKey, _nowPlayIndex);
        CacheModel.get().cachePlayList(_playList);
        return music;
      } else {
        _nowPlayIndex -= 1;
        _sharedPreferences.setInt(_nowPlayIndexKey, _nowPlayIndex);
        return _playList[_nowPlayIndex];
      }
    }
  }

  /// 下一曲
  MusicDataContent? _getNextMusic() {
    // 播放列表是空的：用户没播放过歌曲
    if (_playList.isEmpty) {
      MusicDataContent? music = _getSongs();
      if (null == music) {
        return null;
      }
      _playList.add(music);
      _nowPlayIndex = 0;
      _sharedPreferences.setInt(_nowPlayIndexKey, _nowPlayIndex);
      CacheModel.get().cachePlayListAddOne(music);
      return music;
    } else {
      // 播放列表不是空的，尝试索引位置+1
      if (_playList.length <= _nowPlayIndex + 1) {
        // 说明播放到播放列表中最后一首歌了，需要获取下一首
        MusicDataContent? music = _getSongs();
        if (null == music) {
          return null;
        }
        _playList.add(music);
        _nowPlayIndex = _playList.length - 1;
        _sharedPreferences.setInt(_nowPlayIndexKey, _nowPlayIndex);
        CacheModel.get().cachePlayListAddOne(music);
        return music;
      } else {
        // 不是最后一首，索引+1返回
        _nowPlayIndex += 1;
        _sharedPreferences.setInt(_nowPlayIndexKey, _nowPlayIndex);
        return _playList[_nowPlayIndex];
      }
    }
  }

  /// 获取一首
  MusicDataContent? _getSongs({bool noLoop = false}) {
    switch (_playMode) {
      case 'sequence':
        return _getSongsSequence();
      case 'randomly':
        return _getSongsRandomly();
      case 'loop':
        return noLoop ? _getSongsSequence() : _getSongsLoop();
      default:
        return _getSongsSequence();
    }
  }

  /// 随机获取一首
  MusicDataContent? _getSongsRandomly() {
    if (_musicList.isEmpty) {
      return null;
    }
    List<MusicDataContent> canPlayList =
        _musicList.where((music) => !_randomPlayedSet.contains(music)).toList();
    if (canPlayList.isEmpty) {
      _randomPlayedSet.clear();
      canPlayList = _musicList;
    }
    int index = Random().nextInt(canPlayList.length);
    MusicDataContent randomlyMusic = canPlayList[index];
    _randomPlayedSet.add(randomlyMusic);
    return randomlyMusic;
  }

  /// 顺序获取一首
  MusicDataContent? _getSongsSequence() {
    if (_musicList.isEmpty) {
      return null;
    }
    if (musicList.length <= nowMusicIndex + 1) {
      nowMusicIndex == -1;
    }
    return _musicList[++_nowMusicIndex];
  }

  /// 循环获取一首
  MusicDataContent? _getSongsLoop() {
    if (_musicList.isEmpty) {
      return null;
    }
    return _musicList[_nowMusicIndex];
  }
}
