import 'package:flutter/services.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/provider/play_status_model.dart';
import 'package:yunshu_music/util/common_utils.dart';

class PlayStatusChannel {
  static PlayStatusChannel? _instance;

  static PlayStatusChannel get() {
    _instance ??= PlayStatusChannel();
    return _instance!;
  }

  static const _platform = MethodChannel('yunshu.music/playStatus');

  Future<void> init() async {
    _platform.setMethodCallHandler((call) async {
      LogHelper.get().error('call: ${call.method}');
      switch (call.method) {
        case 'toPrevious':
          await MusicDataModel.get().toPrevious();
          break;
        case 'changePlay':
          bool play = call.arguments;
          await PlayStatusModel.get().setPlay(play);
          break;
        case 'toNext':
          await MusicDataModel.get().toNext();
          break;
      }
    });
  }

  Future<void> setNowPlayMusicInfo(
      String name, String singer, String? cover) async {
    await _platform.invokeMethod('setNowPlayMusicInfo', <String, dynamic>{
      'name': name,
      'singer': singer,
      'cover': cover,
    });
  }

  Future<void> setNowPlayMusicStatus(bool play) async {
    await _platform.invokeMethod('setNowPlayMusicStatus', play);
  }
}
