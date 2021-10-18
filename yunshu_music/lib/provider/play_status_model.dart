import 'package:flutter/material.dart';
import 'package:yunshu_music/method_channel/music_channel.dart';
import 'package:yunshu_music/provider/music_data_model.dart';

/// 播放状态
class PlayStatusModel extends ChangeNotifier {
  static PlayStatusModel? _instance;

  static PlayStatusModel get() {
    _instance ??= PlayStatusModel();
    return _instance!;
  }

  /// 播放进度，实时
  Duration _position = const Duration();

  /// 音频持续时间
  Duration _duration = const Duration();

  /// 缓冲时间
  Duration _bufferedPosition = const Duration();

  int _state = 0;

  /// 当前播放进度
  Duration get position => _position;

  /// 当前音频时长
  Duration get duration => _duration;

  /// 缓冲时间
  Duration get bufferedPosition => _bufferedPosition;

  /// 播放器状态
  bool get processingState => _state == 8;

  /// 现在正在播放吗？
  bool get isPlayNow => _state == 3;

  PlayStatusModel() {
    MusicChannel.get().metadataEvent.listen((event) {
      _duration = Duration(milliseconds: event['duration']);
      MusicDataModel.get().onMetadataChange(event);
      notifyListeners();
    });
    MusicChannel.get().playbackStateEvent.listen((event) {
      double bufferedPosition =
          event['bufferedPosition'] / 100 * _duration.inMilliseconds;
      _bufferedPosition = Duration(milliseconds: bufferedPosition.toInt());
      _position = Duration(milliseconds: event['position']);
      _state = event['state'];
      notifyListeners();
    });
  }

  /// 手动更新播放进度
  Future<void> seek(Duration? position) async {
    if (null == position) {
      return;
    }
    await MusicChannel.get().seekTo(position);
  }

  /// 设置音频源
  Future<void> setSource(String musicId) async {
    await MusicChannel.get().playFromId(musicId);
  }

  /// 设置播放状态
  Future<void> setPlay(bool needPlay) async {
    needPlay
        ? await MusicChannel.get().play()
        : await MusicChannel.get().pause();
  }
}
