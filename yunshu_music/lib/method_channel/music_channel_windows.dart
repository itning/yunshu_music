import 'dart:async';
import 'dart:io';

import 'package:dart_vlc/dart_vlc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:yunshu_music/method_channel/music_channel.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/util/common_utils.dart';

class MusicChannelWindows extends MusicChannel {

  static const _methodChannel = MethodChannel('yunshu.music/method_channel');

  late Stream<dynamic> playbackStateEvent;

  late Stream<dynamic> metadataEvent;

  late Player player;

  Future<void> init() async {
    if (!Platform.isWindows) {
      LogHelper().error('非windows平台调用');
      return;
    }
    LogHelper().debug('初始化DartVLC');
    DartVLC.initialize();
    player = Player(id: 69420);
    _methodChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'getMusicList':
          return MusicDataModel.get().musicList.map((e) => e.toJson()).toList();
        default:
      }
    });
    if (kIsWeb) {
      StreamController<dynamic> playbackStateController =
      StreamController<dynamic>();
      playbackStateEvent = playbackStateController.stream;
      const MethodChannel('yunshu.music/playback_state_event_channel')
          .setMethodCallHandler((call) async {
        playbackStateController.sink.add(call.arguments);
      });

      StreamController<dynamic> metadataEventController =
      StreamController<dynamic>();
      metadataEvent = metadataEventController.stream;
      const MethodChannel('yunshu.music/metadata_event_channel')
          .setMethodCallHandler((call) async {
        metadataEventController.sink.add(call.arguments);
      });
    } else {
      EventChannel _playbackStateEventChannel =
      const EventChannel('yunshu.music/playback_state_event_channel');
      playbackStateEvent = _playbackStateEventChannel.receiveBroadcastStream();
      EventChannel _metadataEventChannel =
      const EventChannel('yunshu.music/metadata_event_channel');
      metadataEvent = _metadataEventChannel.receiveBroadcastStream();
    }
  }

  Future<void> initMethod() async {}

  Future<void> playFromId(String id) async {}

  Future<void> play() async {}

  Future<void> pause() async {}

  Future<void> skipToPrevious() async {}

  Future<void> skipToNext() async {}

  Future<void> seekTo(Duration position) async {}

  Future<void> setPlayMode(String mode) async {}

  Future<String> getPlayMode() async {
    return 'sequence';
  }

  Future<List<dynamic>> getPlayList() async {
    return [];
  }

  Future<void> delPlayListByMediaId(String mediaId) async {}
}
