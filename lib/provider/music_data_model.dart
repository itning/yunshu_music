import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_rest_template/response_entity.dart';
import 'package:yunshu_music/component/lyric/lyric.dart';
import 'package:yunshu_music/component/lyric/lyric_util.dart';
import 'package:yunshu_music/net/http_helper.dart';
import 'package:yunshu_music/net/model/music_entity.dart';
import 'package:yunshu_music/net/model/music_meta_info_entity.dart';
import 'package:yunshu_music/provider/play_status_model.dart';

/// 音乐数据模型
class MusicDataModel extends ChangeNotifier {
  static MusicDataModel? _instance;

  static MusicDataModel get() {
    _instance ??= MusicDataModel();
    return _instance!;
  }

  bool _isInit = false;

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

  /// 获取音乐列表
  List<MusicDataContent> get musicList => _musicList;

  /// 获取当前歌词信息
  List<Lyric>? get lyricList => _lyricList;

  /// 获取音乐封面
  String? get coverBase64 => _coverBase64;

  /// 获取正在播放的音乐在_musicList里的索引
  int get nowMusicIndex => _nowMusicIndex;

  /// 刷新音乐列表
  Future<String?> refreshMusicList({bool needInit = false}) async {
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
    if (needInit) {
      await _initPlay();
    }
    notifyListeners();
  }

  /// 搜索音乐和歌手
  List<MusicDataContent> search(String keyword) {
    if (keyword.trim() == '') {
      return [];
    }
    List<MusicDataContent> searchResultList = _musicList.where((musicItem) {
      bool containsName = false;
      bool containsSinger = false;
      if (musicItem.name != null) {
        containsName = musicItem.name!.contains(keyword);
      }
      if (musicItem.singer != null) {
        containsSinger = musicItem.singer!.contains(keyword);
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
    MusicDataContent music = _musicList[index];
    // 检查播放列表有没有这首歌，有的话直接将播放
    for (int i = 0; i < _playList.length; i++) {
      if (music.musicId == _playList[i].musicId) {
        _nowPlayIndex = i;
        await doPlay();
        return;
      }
    }
    _playList.add(music);
    _nowPlayIndex = _playList.length - 1;
    await doPlay();
  }

  /// 初始化播放信息，这时候没播放但是应该让用户知道播放哪首歌
  Future<void> _initPlay() async {
    if (_isInit) {
      return;
    }
    _isInit = true;
    // TODO ITNING:历史播放列表的读取
    // 移除在所有音乐列表中不存在的历史播放歌曲，初始化完成后调用
    MusicDataContent? music = _getNextMusic();
    if (null == music) {
      return;
    }
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
      print('下一曲为空');
      return;
    }
    await doPlay();
  }

  Future<void> _initLyric(String lyricId) async {
    String? lyric = await HttpHelper.get().getLyric(lyricId);
    List<Lyric>? list = LyricUtil.formatLyric(lyric);
    _lyricList = list;
    notifyListeners();
  }

  Future<void> _initCover(String musicId) async {
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
    print(">>>初始化封面完成 有封面：${null != _coverBase64}");
    notifyListeners();
  }

  /// 上一曲
  MusicDataContent? _getPreviousMusic() {
    // 如果播放列表为空则获取一首歌曲
    if (_playList.isEmpty) {
      // TODO ITNING:歌曲模式
      MusicDataContent? music = _getSongsRandomly();
      if (null == music) {
        return null;
      }
      _playList.insert(0, music);
      _nowPlayIndex = 0;
      return music;
    } else {
      // 播放列表不是空的，尝试索引位置-1
      if (_nowPlayIndex - 1 < 0) {
        // 说明是上一首歌不存在了，获取一首
        MusicDataContent? music = _getSongsRandomly();
        if (null == music) {
          return null;
        }
        _playList.insert(0, music);
        _nowPlayIndex = 0;
        return music;
      } else {
        return _playList[--_nowPlayIndex];
      }
    }
  }

  /// 下一曲
  MusicDataContent? _getNextMusic() {
    // 播放列表是空的：用户没播放过歌曲
    if (_playList.isEmpty) {
      // TODO ITNING:歌曲模式
      MusicDataContent? music = _getSongsRandomly();
      if (null == music) {
        return null;
      }
      _playList.add(music);
      _nowPlayIndex = 0;
      return music;
    } else {
      // 播放列表不是空的，尝试索引位置+1
      if (_playList.length <= _nowPlayIndex + 1) {
        // 说明播放到播放列表中最后一首歌了，需要获取下一首
        MusicDataContent? music = _getSongsRandomly();
        if (null == music) {
          return null;
        }
        _playList.add(music);
        _nowPlayIndex = _playList.length - 1;
        return music;
      } else {
        // 不是最后一首，索引+1返回
        return _playList[++_nowPlayIndex];
      }
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
    return canPlayList[index];
  }
}
