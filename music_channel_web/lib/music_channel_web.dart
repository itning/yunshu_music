import 'dart:async';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:music_channel_web/music_data.dart';
import 'package:music_channel_web/music_player.dart';
import 'package:music_platform_interface/music_model.dart';
import 'package:music_platform_interface/music_platform_interface.dart';

class MusicChannel extends MusicPlatform {
  static MusicChannel? _instance;

  static MusicChannel get() {
    _instance ??= MusicChannel();
    return _instance!;
  }

  static void registerWith(Registrar registrar) {
    MusicPlatform.instance = MusicChannel.get();
  }

  late StreamController<dynamic> metadataEventController;
  late StreamController<dynamic> playbackStateController;

  @override
  Future<void> init(StreamController<dynamic> metadataEventController,
      StreamController<dynamic> playbackStateController) async {
    this.metadataEventController = metadataEventController;
    this.playbackStateController = playbackStateController;
  }

  @override
  Future<void> delPlayListByMediaId(String mediaId) async {
    MusicData.get().delPlayListByMediaId(mediaId);
  }

  @override
  Future<List> getPlayList() async {
    return MusicData.get().playList.map((e) => e.toMetaDataMap()).toList();
  }

  @override
  Future<String> getPlayMode() async {
    return MusicData.get().playMode.name().toLowerCase();
  }

  @override
  Future<void> initMethod(List<Map> musicList) async {
    List<Music> musics = musicList.map((item) => Music.fromMap(item)).toList();
    try {
      MusicData.get().addMusic(musics);
      MusicPlayer.get()
          .onPlayFromMediaId(MusicData.get().nowPlayMusic!.musicId!);
    } catch (e) {
      print(e);
    }
  }

  @override
  Future<void> pause() async {
    MusicPlayer.get().onPause();
  }

  @override
  Future<void> play() async {
    MusicPlayer.get().onPlay();
  }

  @override
  Future<void> playFromId(String id) async {
    MusicPlayer.get().onPlayFromMediaId(id);
  }

  @override
  Future<void> seekTo(Duration position) async {
    MusicPlayer.get().onSeekTo(position.inMilliseconds);
  }

  @override
  Future<void> setPlayMode(String mode) async {
    MusicData.get().playMode = valueOf(mode.toString().toUpperCase());
  }

  @override
  Future<void> skipToNext() async {
    MusicPlayer.get().onSkipToNext(true);
  }

  @override
  Future<void> skipToPrevious() async {
    MusicPlayer.get().onSkipToPrevious(true);
  }
}
