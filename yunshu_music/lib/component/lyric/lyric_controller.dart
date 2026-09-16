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

import 'package:flutter/material.dart';

class LyricController extends ChangeNotifier {
  /// 当前播放进度
  Duration position = const Duration();

  /// 当前进度
  Duration progress = const Duration();

  //滑动保持器
  Timer? draggingTimer;

  //滑动保持时间
  Duration? draggingTimerDuration;

  bool _isDragging = false;

  bool get isDragging => _isDragging;

  set isDragging(bool value) {
    _isDragging = value;
    notifyListeners();
  }

  void reset() {
    progress = const Duration();
    draggingTimer = null;
    draggingTimerDuration = null;
    _isDragging = false;
    draggingOffset = null;
    previousRowOffset = 0;
    oldLine = 0;
    draggingLine = 0;
  }

  Duration draggingProgress = Duration.zero;

  late Function draggingComplete;

  double? draggingOffset;

  //动画 存放上一次偏移量
  double previousRowOffset = 0;

  int oldLine = 0;
  int draggingLine = 0;

  /// 拖动结束且超时未跳转时触发，由视图实现回弹动画。
  VoidCallback? onDraggingAutoReset;

  void updatePosition(Duration value) {
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
    _isDragging = true;
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
    position = draggingProgress;
    _isDragging = false;
    draggingOffset = null;
    notifyListeners();
  }

  /// 自动回弹：退出拖动但保留播放进度。
  void cancelDragging() {
    _cancelTimer();
    _isDragging = false;
    draggingOffset = null;
    notifyListeners();
  }

  void _cancelTimer() {
    draggingTimer?.cancel();
    draggingTimer = null;
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }
}
