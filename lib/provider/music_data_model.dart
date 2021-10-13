import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_rest_template/response_entity.dart';
import 'package:yunshu_music/component/lyric/lyric.dart';
import 'package:yunshu_music/component/lyric/lyric_util.dart';
import 'package:yunshu_music/method_channel/music_channel.dart';
import 'package:yunshu_music/net/http_helper.dart';
import 'package:yunshu_music/net/model/music_entity.dart';
import 'package:yunshu_music/net/model/music_meta_info_entity.dart';
import 'package:yunshu_music/provider/cache_model.dart';

/// 音乐数据模型
class MusicDataModel extends ChangeNotifier {
  static MusicDataModel? _instance;

  static MusicDataModel get() {
    _instance ??= MusicDataModel();
    return _instance!;
  }

  /// 所有音乐列表
  List<MusicDataContent> _musicList = [];

  /// 正在播放的音乐在_musicList里的索引
  int _nowMusicIndex = -1;

  /// 当前歌曲的歌词信息
  List<Lyric>? _lyricList;

  /// 音乐封面
  Uint8List? _coverBase64;

  /// 播放模式
  String _playMode = 'sequence';

  /// 现在播放的音乐
  MusicDataContent? _nowPlayMusic;

  /// 上一首歌曲ID
  String? lastMusicId;

  /// 获取音乐列表
  List<MusicDataContent> get musicList => _musicList;

  /// 获取当前歌词信息
  List<Lyric>? get lyricList => _lyricList;

  /// 获取音乐封面
  Uint8List? get coverBase64 => _coverBase64;

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
        await MusicChannel.get().initMethod();
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
      await MusicChannel.get().initMethod();
    }
    notifyListeners();
  }

  Future<void> init() async {}

  Future<void> nextPlayMode() async {
    switch (_playMode) {
      case 'sequence':
        _playMode = 'randomly';
        await MusicChannel.get().setPlayMode(_playMode);
        notifyListeners();
        break;
      case 'randomly':
        _playMode = 'loop';
        await MusicChannel.get().setPlayMode(_playMode);
        notifyListeners();
        break;
      case 'loop':
        _playMode = 'sequence';
        await MusicChannel.get().setPlayMode(_playMode);
        notifyListeners();
        break;
      default:
        _playMode = 'sequence';
        await MusicChannel.get().setPlayMode(_playMode);
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
        containsName = musicItem.name!.toLowerCase().contains(lowerCaseKeyword);
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
    return _nowPlayMusic;
  }

  /// 设置现在正在播放的音乐信息
  Future<void> setNowPlayMusicUseMusicId(String? musicId) async {
    if (null == musicId) {
      return;
    }
    MusicChannel.get().playFromId(musicId);
  }

  Future<void> onMetadataChange(dynamic event) async {
    String title = event['title'];
    String subTitle = event['subTitle'];
    String mediaId = event['mediaId'];
    String iconUri = event['iconUri'];
    if (mediaId == lastMusicId) {
      return;
    }
    lastMusicId = mediaId;
    _nowPlayMusic = MusicDataContent();
    _nowPlayMusic!.musicId = mediaId;
    _nowPlayMusic!.name = title;
    _nowPlayMusic!.singer = subTitle;
    _nowPlayMusic!.lyricId = mediaId;
    _nowMusicIndex =
        musicList.indexWhere((element) => element.musicId == mediaId);
    notifyListeners();
    await _initCover(mediaId);
    await _initLyric(mediaId);
  }

  /// 上一曲
  Future<void> toPrevious() async {
    if (_musicList.isEmpty) {
      return;
    }
    await MusicChannel.get().skipToPrevious();
  }

  /// 下一曲
  Future<void> toNext() async {
    if (_musicList.isEmpty) {
      return;
    }
    await MusicChannel.get().skipToNext();
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
    File coverFromCache = await CacheModel.get().getCover(musicId);
    if (coverFromCache.existsSync()) {
      _coverBase64 = await coverFromCache.readAsBytes();
      notifyListeners();
      return;
    }
    ResponseEntity<MusicMetaInfoEntity> responseEntity =
    await HttpHelper.get().getMetaInfo(musicId);
    if (responseEntity.status.value != 200) {
      File defaultCoverFile = await CacheModel.get().getDefaultCover();
      _coverBase64 = await defaultCoverFile.readAsBytes();
      notifyListeners();
      return;
    }

    if (responseEntity.body == null || responseEntity.body!.data == null) {
      File defaultCoverFile = await CacheModel.get().getDefaultCover();
      _coverBase64 = await defaultCoverFile.readAsBytes();
      notifyListeners();
      return;
    }

    if (responseEntity.body!.data!.coverPictures == null) {
      File defaultCoverFile = await CacheModel.get().getDefaultCover();
      _coverBase64 = await defaultCoverFile.readAsBytes();
      notifyListeners();
      return;
    }

    if (responseEntity.body!.data!.coverPictures!.isEmpty) {
      File defaultCoverFile = await CacheModel.get().getDefaultCover();
      _coverBase64 = await defaultCoverFile.readAsBytes();
      notifyListeners();
      return;
    }

    MusicMetaInfoDataCoverPictures pictures =
    responseEntity.body!.data!.coverPictures![0];
    File? coverFile = await CacheModel.get()
        .cacheCover(musicId, pictures.base64, pictures.mimeType);
    File defaultCoverFile = await CacheModel.get().getDefaultCover();
    _coverBase64 = coverFile == null
        ? await defaultCoverFile.readAsBytes()
        : await coverFile.readAsBytes();
    notifyListeners();
  }
}
