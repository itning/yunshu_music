import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:music_channel/music_data.dart';
import 'package:music_channel/music_model.dart';
import 'package:music_channel/music_player.dart';

/// A web implementation of the MusicChannel plugin.
class MusicChannelWeb {
  static late MethodChannel _methodChannel;

  static late MethodChannel playbackStateEventChannel;
  static late MethodChannel metadataEventChannel;

  static void registerWith(Registrar registrar) {
    _methodChannel = MethodChannel(
      'yunshu.music/method_channel',
      const StandardMethodCodec(),
      registrar,
    );
    playbackStateEventChannel = MethodChannel(
        'yunshu.music/playback_state_event_channel',
        const StandardMethodCodec(),
        registrar);
    metadataEventChannel = MethodChannel('yunshu.music/metadata_event_channel',
        const StandardMethodCodec(), registrar);

    final pluginInstance = MusicChannelWeb();
    _methodChannel.setMethodCallHandler(pluginInstance.handleMethodCall);
  }

  /// Handles method calls over the MethodChannel of this plugin.
  /// Note: Check the "federated" architecture for a new way of doing this:
  /// https://flutter.dev/go/federated-plugins
  Future<dynamic> handleMethodCall(MethodCall call) async {
    print('handleMethodCall ${call.method} ${call.arguments}');
    switch (call.method) {
      case 'init':
        List<Map>? list =
            await _methodChannel.invokeListMethod<Map>('getMusicList');
        if (null == list) {
          return null;
        }
        List<Music> musics = list.map((item) => Music.fromMap(item)).toList();
        try {
          MusicData.get().addMusic(musics);
          MusicPlayer.get()
              .onPlayFromMediaId(MusicData.get().nowPlayMusic!.musicId!);
        } catch (e) {
          print(e);
        }
        break;
      case 'playFromId':
        dynamic id = call.arguments['id'];
        if (null == id) {
          return null;
        }
        MusicPlayer.get().onPlayFromMediaId(id);
        break;
      case 'play':
        MusicPlayer.get().onPlay();
        break;
      case 'pause':
        MusicPlayer.get().onPause();
        break;
      case 'skipToPrevious':
        MusicPlayer.get().onSkipToPrevious();
        break;
      case 'skipToNext':
        MusicPlayer.get().onSkipToNext();
        break;
      case 'seekTo':
        dynamic pos = call.arguments['position'];
        if (null == pos) {
          return null;
        }
        MusicPlayer.get().onSeekTo(pos);
        break;
      case 'setPlayMode':
        dynamic mode = call.arguments['mode'];
        if (null == mode) {
          return null;
        }
        MusicData.get().playMode = valueOf(mode.toString().toUpperCase());
        break;
      case 'getPlayMode':
        return MusicData.get().playMode.name().toLowerCase();
      case 'getPlayList':
        return MusicData.get().playList.map((e) => e.toMetaDataMap()).toList();
      case 'delPlayListByMediaId':
        dynamic mediaId = call.arguments['mediaId'];
        if (null == mediaId) {
          return null;
        }
        MusicData.get().delPlayListByMediaId(mediaId);
        break;
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details:
              'music_channel for web doesn\'t implement \'${call.method}\'',
        );
    }
    return null;
  }
}
