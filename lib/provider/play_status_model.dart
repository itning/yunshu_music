import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:yunshu_music/provider/music_data_model.dart';

/// 播放状态
class PlayStatusModel extends ChangeNotifier {
  static PlayStatusModel? _instance;

  static PlayStatusModel get() {
    _instance ??= PlayStatusModel();
    return _instance!;
  }

  final AudioPlayer _player;

  /// 播放进度，实时
  Duration _position = const Duration();

  /// 音频持续时间
  Duration _duration = const Duration();

  // TODO ITNING:https://pub.dev/packages/audio_session/install 增加占用监听

  PlayStatusModel() : _player = AudioPlayer() {
    _player.bufferedPositionStream.listen((event) {
      print('>>>缓冲 $event');
    });
    _player.durationStream.listen((event) {
      print('>>>音频持续时间 $event');
      _duration = event ?? const Duration();
    });
    _player.playbackEventStream.listen((event) {
      print('>>>playbackEventStream $event');
    });
    _player.volumeStream.listen((event) {
      print('>>>音量 $event');
    });
    _player.speedStream.listen((event) {
      print('>>>速度 $event');
    });
    _player.positionStream.listen((event) {
      print('>>>播放进度 $event');
      _position = event;
      notifyListeners();
    });
    _player.playingStream.listen((event) {
      print('>>>正在播放状态 $event');
    });
    _player.playerStateStream.listen((event) {
      print('>>>播放状态 $event');
    });
    _player.processingStateStream.listen((event) {
      print('>>>状态改变 $event');
      if (event == ProcessingState.completed) {
        MusicDataModel.get().toNext();
      }
    });
  }

  @override
  void dispose() {
    print('>>>PlayStatusModel dispose');
    _player.dispose();
    super.dispose();
  }

  /// 当前播放进度
  Duration get position => _position;

  /// 当前音频时长
  Duration get duration => _duration;

  /// 现在正在播放吗？
  bool get isPlayNow =>
      _player.playing && _player.processingState != ProcessingState.completed;

  /// 手动更新播放进度
  Future<void> seek(Duration? position) async {
    await _player.seek(position);
  }

  /// 设置音频源
  Future<void> setSource(String url) async {
    try {
      Duration? duration = await _player.setUrl(url);
      print('>>>播放时长：$duration');
    } on PlayerException catch (e) {
      // iOS/macOS: maps to NSError.code
      // Android: maps to ExoPlayerException.type
      // Web: maps to MediaError.code
      print("Error code: ${e.code}");
      // iOS/macOS: maps to NSError.localizedDescription
      // Android: maps to ExoPlaybackException.getMessage()
      // Web: a generic message
      print("Error message: ${e.message}");
    } on PlayerInterruptedException catch (e) {
      // This call was interrupted since another audio source was loaded or the
      // player was stopped or disposed before this audio source could complete
      // loading.
      print("Connection aborted: ${e.message}");
    } catch (e) {
      // Fallback for all errors
      print(e);
    }
  }

  /// 设置播放状态
  Future<void> setPlay(bool needPlay) async {
    needPlay ? await _player.play() : await _player.pause();
  }
}
