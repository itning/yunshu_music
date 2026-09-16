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
3. 优化代码
*/
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/component/lyric/lyric.dart';
import 'package:yunshu_music/component/lyric/lyric_controller.dart';
import 'package:yunshu_music/component/lyric/lyric_painter.dart';
import 'package:yunshu_music/component/lyric/lyric_util.dart';
import 'package:yunshu_music/provider/play_status_model.dart';
import 'package:yunshu_music/util/common_utils.dart';

class LyricWidget extends StatefulWidget {
  final List<Lyric> lyrics;
  final List<Lyric>? remarkLyrics;
  final Size size;
  final LyricController controller;
  final TextStyle lyricStyle;
  final TextStyle remarkStyle;
  final TextStyle currLyricStyle;
  final TextStyle currRemarkLyricStyle;
  final TextStyle draggingLyricStyle;
  final TextStyle draggingRemarkLyricStyle;
  final double lyricGap;
  final double remarkLyricGap;
  final bool enableDrag;
  final double? lyricMaxWidth;

  const LyricWidget({
    super.key,
    required this.lyrics,
    this.remarkLyrics,
    required this.size,
    required this.controller,
    this.lyricStyle = const TextStyle(
      color: Colors.white70,
      fontSize: 16,
      fontFamily: 'LXGWWenKaiMono',
    ),
    this.remarkStyle = const TextStyle(
      color: Colors.white70,
      fontSize: 16,
      fontFamily: 'LXGWWenKaiMono',
    ),
    this.currLyricStyle = const TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontFamily: 'LXGWWenKaiMono',
    ),
    TextStyle? currRemarkLyricStyle,
    TextStyle? draggingLyricStyle,
    TextStyle? draggingRemarkLyricStyle,
    this.lyricGap = 10,
    this.remarkLyricGap = 20,
    this.enableDrag = true,
    this.lyricMaxWidth,
  }) : currRemarkLyricStyle = currRemarkLyricStyle ?? currLyricStyle,
       draggingLyricStyle = draggingLyricStyle ?? lyricStyle,
       draggingRemarkLyricStyle = draggingRemarkLyricStyle ?? remarkStyle;

  @override
  State<LyricWidget> createState() => _LyricWidgetState();
}

class _LyricWidgetState extends State<LyricWidget>
    with TickerProviderStateMixin {
  late List<TextPainter> lyricTextPaints;
  late List<TextPainter> subLyricTextPaints;
  late LyricPainter _lyricPainter;
  double totalHeight = 0;
  late AnimationController _animationController;
  VoidCallback? _animationListenerVoidCallbackFunc;
  VoidCallback? _controllerListener;
  int _animationHashCode = -1;

  /// 每行歌词的累计偏移量，_lineOffsets[i] 表示第 i 行相对第一行的偏移
  List<double> _lineOffsets = const [0];

  /// 翻译歌词按结束时间排序后的高度前缀和
  List<double> _remarkPrefix = const [0];

  /// 翻译歌词按结束时间排序后的结束时间
  List<Duration> _remarkEndTimes = const [];

  bool _lineOffsetsDirty = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery 宽度变化会影响文本换行与行高，需要重新计算
    _lineOffsetsDirty = true;
  }

  @override
  void initState() {
    super.initState();
    lyricTextPaints = widget.lyrics
        .map(
          (l) => TextPainter(
            text: TextSpan(text: l.lyric, style: widget.lyricStyle),
            textDirection: TextDirection.ltr,
          ),
        )
        .toList();

    subLyricTextPaints =
        widget.remarkLyrics
            ?.map(
              (l) => TextPainter(
                text: TextSpan(text: l.lyric, style: widget.remarkStyle),
                textDirection: TextDirection.ltr,
              ),
            )
            .toList() ??
        [];

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_animationListenerVoidCallbackFunc != null) {
          _animationController.removeListener(
            _animationListenerVoidCallbackFunc!,
          );
        }
      }
    });
    widget.controller.draggingComplete = () {
      cancelTimer();
      widget.controller.progress = widget.controller.draggingProgress;
      _lyricPainter.draggingLine = null;
      widget.controller.isDragging = false;
    };
    WidgetsBinding.instance.addPostFrameCallback((call) {
      totalHeight = computeScrollY(widget.lyrics.length - 1);
    });
    widget.controller.addListener(_controllerListener = _syncCurrentLine);
  }

  @override
  void dispose() {
    LogHelper.get().debug('dispose LyricWidget');
    cancelTimer();
    if (_controllerListener != null) {
      widget.controller.removeListener(_controllerListener!);
      _controllerListener = null;
    }
    _animationController.dispose();
    widget.controller.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lyricMaxWidth =
        widget.lyricMaxWidth ?? MediaQuery.of(context).size.width;

    _lyricPainter = LyricPainter(
      widget.lyrics,
      lyricTextPaints,
      subLyricTextPaints,
      subLyrics: widget.remarkLyrics,
      lyricTextStyle: widget.lyricStyle,
      subLyricTextStyle: widget.remarkStyle,
      currLyricTextStyle: widget.currLyricStyle,
      lyricGapValue: widget.lyricGap,
      lyricMaxWidth: lyricMaxWidth,
      subLyricGapValue: widget.remarkLyricGap,
      draggingLyricTextStyle: widget.draggingLyricStyle,
      draggingSubLyricTextStyle: widget.draggingRemarkLyricStyle,
      currSubLyricTextStyle: widget.currRemarkLyricStyle,
    );
    _lyricPainter.currentLyricIndex = findLyricIndexByDuration(
      widget.controller.progress,
      widget.lyrics,
    );
    if (widget.controller.isDragging &&
        widget.controller.draggingOffset != null) {
      _lyricPainter.draggingLine = widget.controller.draggingLine;
      _lyricPainter.offset = widget.controller.draggingOffset!;
    } else {
      _lyricPainter.offset = -computeScrollY(_lyricPainter.currentLyricIndex);
    }
    return Selector<PlayStatusModel, Duration>(
      selector: (_, model) => model.position,
      builder: (_, value, Widget? child) {
        widget.controller.progress = value;
        _syncCurrentLine();
        return child!;
      },
      child: widget.enableDrag
          ? GestureDetector(
              onVerticalDragUpdate: (e) {
                cancelTimer();
                double temOffset = (_lyricPainter.offset + e.delta.dy);
                if (temOffset < 0 && temOffset >= -totalHeight) {
                  widget.controller.draggingOffset = temOffset;
                  widget.controller.draggingLine = getCurrentDraggingLine(
                    temOffset + widget.lyricGap,
                  );
                  _lyricPainter.draggingLine = widget.controller.draggingLine;
                  widget.controller.draggingProgress =
                      widget.lyrics[widget.controller.draggingLine].startTime +
                      const Duration(milliseconds: 1);
                  widget.controller.isDragging = true;
                  _lyricPainter.offset = temOffset;
                }
              },
              onVerticalDragEnd: (e) {
                cancelTimer();
                widget.controller.draggingTimer = Timer(
                  widget.controller.draggingTimerDuration ??
                      const Duration(seconds: 3),
                  () {
                    resetDragging();
                  },
                );
              },
              child: buildCustomPaint(),
            )
          : buildCustomPaint(),
    );
  }

  CustomPaint buildCustomPaint() {
    return CustomPaint(painter: _lyricPainter, size: widget.size);
  }

  void resetDragging() {
    if (!mounted) {
      return;
    }
    if (widget.controller.draggingOffset == null) {
      return;
    }

    _lyricPainter.currentLyricIndex = findLyricIndexByDuration(
      widget.controller.progress,
      widget.lyrics,
    );
    widget.controller.previousRowOffset = -widget.controller.draggingOffset!;
    animationScrollY(_lyricPainter.currentLyricIndex);
    _lyricPainter.draggingLine = null;
    widget.controller.isDragging = false;
  }

  int getCurrentDraggingLine(double offset) {
    for (int i = 0; i < widget.lyrics.length; i++) {
      var scrollY = computeScrollY(i);
      if (offset > -1) {
        offset = 0;
      }
      if (offset >= -scrollY) {
        return i;
      }
    }
    return widget.lyrics.length;
  }

  void cancelTimer() {
    if (widget.controller.draggingTimer != null) {
      if (widget.controller.draggingTimer!.isActive) {
        widget.controller.draggingTimer!.cancel();
        widget.controller.draggingTimer = null;
      }
    }
  }

  void animationScrollY(int currentLyricIndex) {
    if (!mounted) {
      return;
    }
    // 重置动画
    _animationController.reset();
    // 计算当前行偏移量
    var currentRowOffset = computeScrollY(currentLyricIndex);
    // 如果偏移量相同不执行动画
    if (currentRowOffset == widget.controller.previousRowOffset) {
      return;
    }
    // 起始为上一行，结束点为当前行
    Animation animation = Tween<double>(
      begin: widget.controller.previousRowOffset,
      end: currentRowOffset,
    ).animate(_animationController);
    _animationHashCode = animation.hashCode;
    widget.controller.previousRowOffset = currentRowOffset;
    VoidCallback voidCallbackFunc(int hashcode) {
      return () {
        if (_animationHashCode != hashcode) {
          return;
        }
        _lyricPainter.offset = -animation.value;
      };
    }

    if (_animationListenerVoidCallbackFunc != null) {
      _animationController.removeListener(_animationListenerVoidCallbackFunc!);
    }
    _animationListenerVoidCallbackFunc = voidCallbackFunc(animation.hashCode);
    // 动画执行监听
    _animationController.addListener(_animationListenerVoidCallbackFunc!);
    // 开始执行动画
    _animationController.forward();
  }

  /// 根据当前时长获取歌词位置
  int findLyricIndexByDuration(Duration curDuration, List<Lyric> lyrics) =>
      LyricUtil.findIndexByDuration(curDuration, lyrics);

  /// 根据当前进度同步高亮行，必要时触发滚动动画
  void _syncCurrentLine() {
    var curLine = findLyricIndexByDuration(
      widget.controller.progress,
      widget.lyrics,
    );
    if (widget.controller.oldLine != curLine) {
      _lyricPainter.currentLyricIndex = curLine;
      if (!widget.controller.isDragging) {
        animationScrollY(curLine);
      }
      widget.controller.oldLine = curLine;
    }
  }

  /// 计算传入行和第一行的偏移量
  double computeScrollY(int curLine) {
    if (curLine < 0) {
      return 0;
    }
    _ensureLineOffsets();
    double totalHeight = _lineOffsets[curLine];
    if (widget.remarkLyrics != null && curLine < widget.lyrics.length) {
      // 增加 当前行之前的翻译歌词的偏移量
      totalHeight += _remarkOffsetBefore(widget.lyrics[curLine].endTime!);
    }
    return totalHeight;
  }

  /// 预计算每行歌词的累计偏移量以及翻译歌词的前缀和，避免重复布局
  void _ensureLineOffsets() {
    if (!_lineOffsetsDirty) {
      return;
    }
    final maxWidth = widget.lyricMaxWidth ?? MediaQuery.of(context).size.width;
    final int count = widget.lyrics.length;
    final List<double> offsets = List<double>.filled(count + 1, 0);
    double total = 0;
    for (int i = 0; i < count; i++) {
      offsets[i] = total;
      var currPaint = lyricTextPaints[i]
        ..text = TextSpan(
          text: widget.lyrics[i].lyric,
          style: widget.lyricStyle,
        );
      currPaint.layout(maxWidth: maxWidth);
      total += currPaint.height + widget.lyricGap;
    }
    offsets[count] = total;
    _lineOffsets = offsets;

    final remarkLyrics = widget.remarkLyrics;
    if (remarkLyrics != null) {
      final List<MapEntry<Duration, double>> entries = [];
      for (int i = 0; i < remarkLyrics.length; i++) {
        var currPaint = subLyricTextPaints[i]
          ..text = TextSpan(
            text: remarkLyrics[i].lyric,
            style: widget.remarkStyle,
          );
        currPaint.layout(maxWidth: maxWidth);
        entries.add(
          MapEntry(
            remarkLyrics[i].endTime!,
            widget.remarkLyricGap + currPaint.height,
          ),
        );
      }
      entries.sort((a, b) => a.key.compareTo(b.key));
      final List<double> prefix = List<double>.filled(entries.length + 1, 0);
      final List<Duration> endTimes = List<Duration>.filled(
        entries.length,
        Duration.zero,
      );
      for (int i = 0; i < entries.length; i++) {
        prefix[i + 1] = prefix[i] + entries[i].value;
        endTimes[i] = entries[i].key;
      }
      _remarkPrefix = prefix;
      _remarkEndTimes = endTimes;
    } else {
      _remarkPrefix = const [0];
      _remarkEndTimes = const [];
    }
    _lineOffsetsDirty = false;
  }

  /// 返回结束时间不晚于 [endTime] 的翻译歌词高度之和
  double _remarkOffsetBefore(Duration endTime) {
    int low = 0;
    int high = _remarkEndTimes.length;
    while (low < high) {
      int mid = low + ((high - low) >> 1);
      if (_remarkEndTimes[mid] <= endTime) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return _remarkPrefix[low];
  }
}
