import 'package:flutter/material.dart';

/// 播放暂停意图
class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

/// 上一曲意图
class PreviousIntent extends Intent {
  const PreviousIntent();
}

/// 下一曲意图
class NextIntent extends Intent {
  const NextIntent();
}

/// 进度后退意图
class SeekBackIntent extends Intent {
  const SeekBackIntent();
}

/// 进度前进意图
class SeekForwardIntent extends Intent {
  const SeekForwardIntent();
}
