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
  /// 当前进度
  Duration progress = const Duration();

  //滑动保持器
  Timer? draggingTimer;

  //滑动保持时间
  Duration? draggingTimerDuration;

  bool _isDragging = false;

  get isDragging => _isDragging;

  set isDragging(value) {
    _isDragging = value;
    notifyListeners();
  }

  clear() {
    _isDragging = false;
  }

  late Duration draggingProgress;

  late Function draggingComplete;

  double? draggingOffset;

  //动画 存放上一次偏移量
  double previousRowOffset = 0;

  int oldLine = 0;
  int draggingLine = 0;

}
