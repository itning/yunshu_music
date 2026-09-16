/*
Copyright [2018] [Caijinglong]

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

修改说明：
1. 适配dart空安全
2. 注释修改
*/
import 'dart:async';

import 'package:flutter/foundation.dart';

/// 页面级歌词状态：播放进度 + 拖动状态。
class LyricController extends ChangeNotifier {
  Duration position = Duration.zero;

  bool isDragging = false;

  double? draggingOffset;

  int draggingLine = 0;

  Duration draggingProgress = Duration.zero;

  /// 滑动保持时间；为空时默认 3 秒。
  Duration? draggingTimerDuration;

  /// 滑动保持器。
  Timer? draggingTimer;

  /// 拖动结束且超时未跳转时触发，由视图实现回弹动画。
  VoidCallback? onDraggingAutoReset;

  /// 点击跳转的目标进度；播放器回传到达前忽略过渡位置。
  Duration? _pendingSeek;
  Duration? _pendingSeekFrom;
  Timer? _pendingSeekTimer;

  static const Duration _seekTimeout = Duration(seconds: 2);

  void updatePosition(Duration value) {
    final Duration? target = _pendingSeek;
    if (target != null) {
      final Duration from = _pendingSeekFrom ?? target;
      // 向前跳转需等待回传 >= 目标；向后跳转需等待回传 < 跳转前位置。
      // 这样可过滤 seek 生效前播放器仍回传的旧位置。
      final bool reached = target >= from ? value >= target : value < from;
      if (!reached) {
        return;
      }
      _clearPendingSeek();
    }
    if (value == position) {
      return;
    }
    position = value;
    notifyListeners();
  }

  void beginDrag({
    required double offset,
    required int line,
    required Duration progress,
  }) {
    _cancelTimer();
    _clearPendingSeek();
    isDragging = true;
    draggingOffset = offset;
    draggingLine = line;
    draggingProgress = progress;
    notifyListeners();
  }

  void updateDrag({
    required double offset,
    required int line,
    required Duration progress,
  }) {
    draggingOffset = offset;
    draggingLine = line;
    draggingProgress = progress;
    notifyListeners();
  }

  void endDrag() {
    _cancelTimer();
    draggingTimer = Timer(
      draggingTimerDuration ?? const Duration(seconds: 3),
      () => onDraggingAutoReset?.call(),
    );
  }

  /// 点击跳转：进度切到拖动位置并退出拖动。
  void completeDrag() {
    _cancelTimer();
    _pendingSeekFrom = position;
    position = draggingProgress;
    _pendingSeek = draggingProgress;
    _pendingSeekTimer?.cancel();
    _pendingSeekTimer = Timer(_seekTimeout, _clearPendingSeek);
    isDragging = false;
    draggingOffset = null;
    notifyListeners();
  }

  /// 自动回弹：退出拖动但保留播放进度。
  void cancelDragging() {
    _cancelTimer();
    isDragging = false;
    draggingOffset = null;
    notifyListeners();
  }

  void _cancelTimer() {
    draggingTimer?.cancel();
    draggingTimer = null;
  }

  void _clearPendingSeek() {
    _pendingSeek = null;
    _pendingSeekFrom = null;
    _pendingSeekTimer?.cancel();
    _pendingSeekTimer = null;
  }

  /// 取消未触发的回弹定时器（视图 dispose 时调用）。
  void cancelDragTimer() {
    _cancelTimer();
  }

  @override
  void dispose() {
    _cancelTimer();
    _clearPendingSeek();
    super.dispose();
  }
}
