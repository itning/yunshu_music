import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:tuple/tuple.dart';
import 'package:yunshu_music/component/lyric/lyric.dart';
import 'package:yunshu_music/component/lyric/lyric_util.dart';
import 'package:yunshu_music/method_channel/music_channel.dart';
import 'package:yunshu_music/net/http_helper.dart';
import 'package:yunshu_music/net/model/music_entity.dart';
import 'package:yunshu_music/provider/play_status_model.dart';
import 'package:yunshu_music/util/common_utils.dart';

/// 音乐数据模型
class MusicDataModel extends ChangeNotifier {
  static MusicDataModel? _instance;

  static MusicDataModel get() {
    _instance ??= MusicDataModel();
    return _instance!;
  }

  /// 所有音乐列表
  List<MusicData> _musicList = [];

  /// 正在播放的音乐在_musicList里的索引
  int _nowMusicIndex = -1;

  /// 当前歌曲的歌词信息
  List<Lyric>? _lyricList;

  /// 音乐封面
  Uint8List? _coverBase64;

  /// 播放模式
  String _playMode = 'sequence';

  /// 现在播放的音乐
  MusicData? _nowPlayMusic;

  /// 上一首歌曲ID
  String? lastMusicId;

  /// 获取音乐列表
  List<MusicData> get musicList => _musicList;

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
    Response<Map<String, dynamic>> response = await HttpHelper.get().getMusic();
    if (response.statusCode != 200) {
      return '服务器状态${response.statusCode}';
    }
    if (response.data == null) {
      return '响应信息为空';
    }
    Map<String, dynamic> body = response.data!;
    MusicEntity musicEntity = MusicEntity.fromJson(body);
    if (musicEntity.data == null) {
      return musicEntity.msg ?? '服务器错误';
    }
    _musicList = musicEntity.data!;
    if (needInit) {
      await MusicChannel.get().initMethod();
    }
    notifyListeners();
    return null;
  }

  Future<void> init() async {
    _playMode = await MusicChannel.get().getPlayMode();
  }

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
  List<MusicData> search(String keyword) {
    if (keyword.trim() == '') {
      return [];
    }
    String lowerCaseKeyword = keyword.toLowerCase();
    List<MusicData> searchResultList = _musicList.where((musicItem) {
      bool containsName = false;
      bool containsSinger = false;
      if (musicItem.name != null) {
        containsName = musicItem.name!.toLowerCase().contains(lowerCaseKeyword);
      }
      if (musicItem.singer != null) {
        containsSinger = musicItem.singer!.toLowerCase().contains(
          lowerCaseKeyword,
        );
      }
      return containsName || containsSinger;
    }).toList();
    return searchResultList;
  }

  /// 获取现在正在播放的音乐信息
  MusicData? getNowPlayMusic() {
    return _nowPlayMusic;
  }

  /// 设置现在正在播放的音乐信息
  Future<void> setNowPlayMusicUseMusicId(String? musicId) async {
    if (null == musicId) {
      return;
    }
    if (_nowPlayMusic != null && _nowPlayMusic!.musicId == musicId) {
      if (!PlayStatusModel.get().isPlayNow) {
        // 虽然是同一首歌但是是暂停状态那么直接进行播放
        PlayStatusModel.get().setPlay(true);
      }
      return;
    }
    MusicChannel.get().playFromId(musicId);
  }

  Future<void> onMetadataChange(dynamic event) async {
    String title = event['title'];
    String subTitle = event['subTitle'];
    String mediaId = event['mediaId'];
    String coverUri = event['coverUri'];
    String lyricUri = event['lyricUri'];
    if (mediaId == lastMusicId) {
      return;
    }
    lastMusicId = mediaId;
    _nowPlayMusic = MusicData();
    _nowPlayMusic!.musicId = mediaId;
    _nowPlayMusic!.name = title;
    _nowPlayMusic!.singer = subTitle;
    _nowPlayMusic!.lyricId = mediaId;
    _nowMusicIndex = musicList.indexWhere(
      (element) => element.musicId == mediaId,
    );
    notifyListeners();
    await _initCover(mediaId, coverUri);
    await _initLyric(mediaId, lyricUri);
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

  Future<void> _initLyric(String lyricId, String lyricUri) async {
    String? lyric = await HttpHelper.get().getLyric(lyricUri);
    List<Lyric>? list = LyricUtil.formatLyric(lyric);
    _lyricList = list;
    notifyListeners();
  }

  Future<void> _initCover(String musicId, String coverUri) async {
    Tuple2<String?, List<int>?> coverBytes = await HttpHelper.get().getCover(
      coverUri,
    );
    if (coverBytes.item2 == null) {
      _coverBase64 = await getDefaultCover();
      notifyListeners();
      return;
    }
    _coverBase64 = Uint8List.fromList(coverBytes.item2!);
    notifyListeners();
  }
}
