import 'dart:async';

import 'package:music_platform_interface/unimplemented_music.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

abstract class MusicPlatform extends PlatformInterface {
  MusicPlatform() : super(token: _token);

  static final Object _token = Object();
  static MusicPlatform _instance = UnimplementedMusic();

  static MusicPlatform get instance => _instance;

  static set instance(MusicPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  Future<void> init(StreamController<dynamic> metadataEventController,
      StreamController<dynamic> playbackStateController,
      StreamController<double> volumeController);

  Future<void> initMethod(List<Map> musicList);

  Future<void> playFromId(String id);

  Future<void> play();

  Future<void> pause();

  Future<void> skipToPrevious();

  Future<void> skipToNext();

  Future<void> seekTo(Duration position);

  Future<void> setPlayMode(String mode);

  Future<String> getPlayMode();

  Future<List<dynamic>> getPlayList();

  Future<void> delPlayListByMediaId(String mediaId);

  Future<void> setVolume(double value);
}
