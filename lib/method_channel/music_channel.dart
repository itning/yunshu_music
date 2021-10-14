import 'dart:async';

import 'package:flutter/services.dart';
import 'package:yunshu_music/provider/music_data_model.dart';

class MusicChannel {
  static MusicChannel? _instance;

  static MusicChannel get() {
    _instance ??= MusicChannel();
    return _instance!;
  }

  static const _methodChannel = MethodChannel('yunshu.music/method_channel');
  static const _playbackStateEventChannel =
      EventChannel('yunshu.music/playback_state_event_channel');
  static const _metadataEventChannel =
      EventChannel('yunshu.music/metadata_event_channel');

  late Stream playbackStateEvent;

  late Stream metadataEvent;

  Future<void> init() async {
    _methodChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'getMusicList':
          return MusicDataModel.get().musicList.map((e) => e.toJson()).toList();
        default:
      }
    });
    playbackStateEvent = _playbackStateEventChannel.receiveBroadcastStream();
    metadataEvent = _metadataEventChannel.receiveBroadcastStream();
  }

  Future<void> initMethod() async {
    await _methodChannel.invokeMethod("init");
  }

  Future<void> playFromId(String id) async {
    await _methodChannel.invokeMethod("playFromId", {'id': id});
  }

  Future<void> play() async {
    await _methodChannel.invokeMethod("play");
  }

  Future<void> pause() async {
    await _methodChannel.invokeMethod("pause");
  }

  Future<void> skipToPrevious() async {
    await _methodChannel.invokeMethod("skipToPrevious");
  }

  Future<void> skipToNext() async {
    await _methodChannel.invokeMethod("skipToNext");
  }

  Future<void> seekTo(Duration position) async {
    await _methodChannel
        .invokeMethod('seekTo', {'position': position.inMilliseconds});
  }

  Future<void> setPlayMode(String mode) async {
    await _methodChannel.invokeMethod('setPlayMode', {'mode': mode});
  }

  Future<String> getPlayMode() async {
    return await _methodChannel.invokeMethod('getPlayMode');
  }

  Future<List<dynamic>> getPlayList() async {
    // List<Map<String,String>>
    return await _methodChannel.invokeMethod('getPlayList');
  }

  Future<void> delPlayListByMediaId(String mediaId) async {
    await _methodChannel
        .invokeMethod('delPlayListByMediaId', {'mediaId': mediaId});
  }
}
