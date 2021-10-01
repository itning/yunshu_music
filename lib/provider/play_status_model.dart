import 'package:flutter/material.dart';

/// 播放状态
class PlayStatusModel extends ChangeNotifier {
  /// 默认是没播放
  bool _playNow = false;

  /// 现在正在播放吗？
  bool get isPlayNow => _playNow;

  /// 设置播放状态
  void setPlay(bool play) {
    _playNow = play;
    notifyListeners();
  }
}
