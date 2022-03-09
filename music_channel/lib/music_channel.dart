import 'dart:async';

import 'package:music_platform_interface/music_platform_interface.dart';

Future<void> init(
    StreamController<dynamic> metadataEventController,
    StreamController<dynamic> playbackStateController,
    StreamController<double> volumeStateController) {
  return MusicPlatform.instance.init(
      metadataEventController, playbackStateController, volumeStateController);
}

Future<void> initMethod(List<Map> musicList) {
  return MusicPlatform.instance.initMethod(musicList);
}

Future<void> playFromId(String id) {
  return MusicPlatform.instance.playFromId(id);
}

Future<void> play() {
  return MusicPlatform.instance.play();
}

Future<void> pause() {
  return MusicPlatform.instance.pause();
}

Future<void> skipToPrevious() {
  return MusicPlatform.instance.skipToPrevious();
}

Future<void> skipToNext() {
  return MusicPlatform.instance.skipToNext();
}

Future<void> seekTo(Duration position) {
  return MusicPlatform.instance.seekTo(position);
}

Future<void> setPlayMode(String mode) {
  return MusicPlatform.instance.setPlayMode(mode);
}

Future<String> getPlayMode() {
  return MusicPlatform.instance.getPlayMode();
}

Future<List<dynamic>> getPlayList() {
  return MusicPlatform.instance.getPlayList();
}

Future<void> delPlayListByMediaId(String mediaId) {
  return MusicPlatform.instance.delPlayListByMediaId(mediaId);
}

Future<void> setVolume(double value) {
  return MusicPlatform.instance.setVolume(value);
}
