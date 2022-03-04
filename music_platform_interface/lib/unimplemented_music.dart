import 'dart:async';

import 'package:music_platform_interface/music_platform_interface.dart';

class UnimplementedMusic extends MusicPlatform{
  @override
  Future<void> delPlayListByMediaId(String mediaId) {
    throw UnimplementedError();
  }

  @override
  Future<List> getPlayList() {
    throw UnimplementedError();
  }

  @override
  Future<String> getPlayMode() {
    throw UnimplementedError();
  }

  @override
  Future<void> init(StreamController<dynamic> metadataEventController, StreamController<dynamic> playbackStateController) {
    throw UnimplementedError();
  }

  @override
  Future<void> initMethod(List<Map<dynamic, dynamic>> musicList) {
    throw UnimplementedError();
  }

  @override
  Future<void> pause() {
    throw UnimplementedError();
  }

  @override
  Future<void> play() {
    throw UnimplementedError();
  }

  @override
  Future<void> playFromId(String id) {
    throw UnimplementedError();
  }

  @override
  Future<void> seekTo(Duration position) {
    throw UnimplementedError();
  }

  @override
  Future<void> setPlayMode(String mode) {
    throw UnimplementedError();
  }

  @override
  Future<void> skipToNext() {
    throw UnimplementedError();
  }

  @override
  Future<void> skipToPrevious() {
    throw UnimplementedError();
  }
}