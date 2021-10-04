import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/util/common_utils.dart';

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

  /// 缓冲时间
  Duration _bufferedPosition = const Duration();

  /// 当前播放进度
  Duration get position => _position;

  /// 当前音频时长
  Duration get duration => _duration;

  /// 缓冲时间
  Duration get bufferedPosition => _bufferedPosition;

  /// 播放器状态
  ProcessingState get processingState => _player.processingState;

  /// 现在正在播放吗？
  bool get isPlayNow =>
      _player.playing &&
      _player.processingState != ProcessingState.completed &&
      _player.processingState != ProcessingState.loading;

  // TODO ITNING:https://pub.dev/packages/audio_session/install 增加占用监听

  PlayStatusModel() : _player = AudioPlayer(userAgent: 'YunShuMusic') {
    _player.bufferedPositionStream.listen((event) {
      _bufferedPosition = event;
      notifyListeners();
    });
    _player.durationStream.listen((event) {
      LogHelper.get().debug('>>>音频持续时间 $event');
      _duration = event ?? const Duration();
    });
    _player.playbackEventStream.listen((event) {
      LogHelper.get().debug('>>>playbackEventStream $event');
    });
    _player.volumeStream.listen((event) {
      LogHelper.get().debug('>>>音量 $event');
    });
    _player.speedStream.listen((event) {
      LogHelper.get().debug('>>>速度 $event');
    });
    _player.positionStream.listen((event) {
      _position = event;
      notifyListeners();
    });
    _player.playingStream.listen((event) {
      LogHelper.get().debug('>>>正在播放状态 $event');
    });
    _player.playerStateStream.listen((event) {
      LogHelper.get().debug('>>>播放状态 $event');
    });
    _player.processingStateStream.listen((event) {
      LogHelper.get().debug('>>>状态改变 $event');
      notifyListeners();
      if (event == ProcessingState.completed) {
        MusicDataModel.get().toNext();
      }
    });
  }

  @override
  void dispose() {
    LogHelper.get().debug('>>>PlayStatusModel dispose');
    _player.dispose();
    super.dispose();
  }

  /// 手动更新播放进度
  Future<void> seek(Duration? position) async {
    await _player.seek(position);
  }

  /// 设置音频源
  Future<void> setSource(String url) async {
    try {
      Duration? duration = await _player.setUrl(url);
      LogHelper.get().debug('>>>播放时长：$duration');
    } on PlayerException catch (e) {
      LogHelper.get().error('设置音频源失败', e);
    } on PlayerInterruptedException catch (e) {
      // This call was interrupted since another audio source was loaded or the
      // player was stopped or disposed before this audio source could complete
      // loading.
      LogHelper.get().warn('设置音频源失败', e);
    } catch (e) {
      LogHelper.get().error('设置音频源失败', e);
    }
  }

  /// 设置播放状态
  Future<void> setPlay(bool needPlay) async {
    needPlay ? await _player.play() : await _player.pause();
  }

  /// 停止播放
  Future<void> stopPlay() async {
    _player.stop();
  }
}
