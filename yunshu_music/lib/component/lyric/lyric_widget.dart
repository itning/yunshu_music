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
import 'package:provider/provider.dart';
import 'package:yunshu_music/component/lyric/lyric.dart';
import 'package:yunshu_music/component/lyric/lyric_controller.dart';
import 'package:yunshu_music/component/lyric/lyric_painter.dart';
import 'package:yunshu_music/provider/play_status_model.dart';

class LyricWidget extends StatefulWidget {
  final List<Lyric> lyrics;
  final List<Lyric>? remarkLyrics;
  final Size size;
  final LyricController controller;
  late TextStyle lyricStyle;
  late TextStyle remarkStyle;
  late TextStyle currLyricStyle;
  late TextStyle currRemarkLyricStyle;
  late TextStyle draggingLyricStyle;
  late TextStyle draggingRemarkLyricStyle;
  final double lyricGap;
  final double remarkLyricGap;
  bool enableDrag;

  /// 歌词画笔数组
  List<TextPainter> lyricTextPaints = [];

  /// 翻译/音译歌词画笔数组
  List<TextPainter> subLyricTextPaints = [];

  /// 字体最大宽度
  double? lyricMaxWidth;

  LyricWidget(
      {Key? key,
      required this.lyrics,
      this.remarkLyrics,
      required this.size,
      required this.controller,
      TextStyle? lyricStyle,
      TextStyle? remarkStyle,
      TextStyle? currLyricStyle,
      this.lyricGap = 10,
      this.remarkLyricGap = 20,
      TextStyle? draggingLyricStyle,
      TextStyle? draggingRemarkLyricStyle,
      this.enableDrag = true,
      this.lyricMaxWidth,
      TextStyle? currRemarkLyricStyle})
      : assert(lyrics.isNotEmpty),
        super(key: key) {
    this.lyricStyle =
        lyricStyle ??= const TextStyle(color: Colors.white70, fontSize: 16);
    this.remarkStyle =
        remarkStyle ??= const TextStyle(color: Colors.white70, fontSize: 16);
    this.currLyricStyle =
        currLyricStyle ??= const TextStyle(color: Colors.white, fontSize: 16);
    this.currRemarkLyricStyle = currRemarkLyricStyle ??= this.currLyricStyle;
    this.draggingLyricStyle =
        draggingLyricStyle ??= lyricStyle.copyWith(color: Colors.grey[300]);
    this.draggingRemarkLyricStyle = draggingRemarkLyricStyle ??=
        remarkStyle.copyWith(color: Colors.grey[300]);

    //歌词转画笔
    lyricTextPaints.addAll(lyrics
        .map(
          (l) => TextPainter(
              text: TextSpan(text: l.lyric, style: lyricStyle),
              textDirection: TextDirection.ltr),
        )
        .toList());

    //翻译/音译歌词转画笔
    if (remarkLyrics != null && remarkLyrics!.isNotEmpty) {
      subLyricTextPaints.addAll(remarkLyrics!
          .map((l) => TextPainter(
              text: TextSpan(text: l.lyric, style: remarkStyle),
              textDirection: TextDirection.ltr))
          .toList());
    }
  }

  @override
  _LyricWidgetState createState() => _LyricWidgetState();
}

class _LyricWidgetState extends State<LyricWidget> {
  late LyricPainter _lyricPainter;
  double totalHeight = 0;

  @override
  void initState() {
    widget.controller.draggingComplete = () {
      cancelTimer();
      widget.controller.progress = widget.controller.draggingProgress;
      _lyricPainter.draggingLine = null;
      widget.controller.isDragging = false;
    };
    WidgetsBinding.instance!.addPostFrameCallback((call) {
      totalHeight = computeScrollY(widget.lyrics.length - 1);
    });
    widget.controller.addListener(() {
      var curLine =
          findLyricIndexByDuration(widget.controller.progress, widget.lyrics);
      if (widget.controller.oldLine != curLine) {
        _lyricPainter.currentLyricIndex = curLine;
        if (!widget.controller.isDragging) {
          if (widget.controller.vsync == null) {
            _lyricPainter.offset = -computeScrollY(curLine);
          } else {
            animationScrollY(curLine, widget.controller.vsync!);
          }
        }
        widget.controller.oldLine = curLine;
      }
    });
    super.initState();
  }

  ///因空行高度与非空行高度不一致，获取非空行的位置
  int getNotEmptyLineHeight(List<Lyric> lyrics) =>
      lyrics.indexOf(lyrics.firstWhere((lyric) => lyric.lyric.trim().isNotEmpty,
          orElse: () => lyrics.first));

  @override
  Widget build(BuildContext context) {
    if (widget.lyricMaxWidth == null ||
        widget.lyricMaxWidth == double.infinity) {
      widget.lyricMaxWidth = MediaQuery.of(context).size.width;
    }

    _lyricPainter = LyricPainter(
        widget.lyrics, widget.lyricTextPaints, widget.subLyricTextPaints,
        vsync: widget.controller.vsync,
        subLyrics: widget.remarkLyrics,
        lyricTextStyle: widget.lyricStyle,
        subLyricTextStyle: widget.remarkStyle,
        currLyricTextStyle: widget.currLyricStyle,
        lyricGapValue: widget.lyricGap,
        lyricMaxWidth: widget.lyricMaxWidth!,
        subLyricGapValue: widget.remarkLyricGap,
        draggingLyricTextStyle: widget.draggingLyricStyle,
        draggingSubLyricTextStyle: widget.draggingRemarkLyricStyle,
        currSubLyricTextStyle: widget.currRemarkLyricStyle);
    _lyricPainter.currentLyricIndex =
        findLyricIndexByDuration(widget.controller.progress, widget.lyrics);
    if (widget.controller.isDragging) {
      _lyricPainter.draggingLine = widget.controller.draggingLine;
      _lyricPainter.offset = widget.controller.draggingOffset;
    } else {
      _lyricPainter.offset = -computeScrollY(_lyricPainter.currentLyricIndex);
    }
    return Selector<PlayStatusModel, Duration>(
      selector: (_, model) => model.position,
      builder: (_, value, Widget? child) {
        widget.controller.progress = value;
        var curLine =
            findLyricIndexByDuration(widget.controller.progress, widget.lyrics);
        if (widget.controller.oldLine != curLine) {
          _lyricPainter.currentLyricIndex = curLine;
          if (!widget.controller.isDragging) {
            if (widget.controller.vsync == null) {
              _lyricPainter.offset = -computeScrollY(curLine);
            } else {
              animationScrollY(curLine, widget.controller.vsync!);
            }
          }
          widget.controller.oldLine = curLine;
        }
        return child!;
      },
      child: widget.enableDrag
          ? GestureDetector(
              onVerticalDragUpdate: (e) {
                cancelTimer();
                double temOffset = (_lyricPainter.offset + e.delta.dy);
                if (temOffset < 0 && temOffset >= -totalHeight) {
                  widget.controller.draggingOffset = temOffset;
                  widget.controller.draggingLine =
                      getCurrentDraggingLine(temOffset + widget.lyricGap);
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
                        const Duration(seconds: 3), () {
                  resetDragging();
                });
              },
              child: buildCustomPaint(),
            )
          : buildCustomPaint(),
    );
  }

  CustomPaint buildCustomPaint() {
    return CustomPaint(
      painter: _lyricPainter,
      size: widget.size,
    );
  }

  void resetDragging() {
    _lyricPainter.currentLyricIndex =
        findLyricIndexByDuration(widget.controller.progress, widget.lyrics);

    widget.controller.previousRowOffset = -widget.controller.draggingOffset!;
    animationScrollY(_lyricPainter.currentLyricIndex, widget.controller.vsync!);
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

  animationScrollY(currentLyricIndex, TickerProvider tickerProvider) {
    var animationController = widget.controller.animationController;
    if (animationController != null) {
      animationController.stop();
    }
    animationController = AnimationController(
        vsync: tickerProvider, duration: const Duration(milliseconds: 300))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          animationController!.dispose();
          animationController = null;
        }
      });
    // 计算当前行偏移量
    var currentRowOffset = computeScrollY(currentLyricIndex);
    //如果偏移量相同不执行动画
    if (currentRowOffset == widget.controller.previousRowOffset) {
      return;
    }
    // 起始为上一行，结束点为当前行
    Animation animation = Tween<double>(
            begin: widget.controller.previousRowOffset, end: currentRowOffset)
        .animate(animationController!);
    widget.controller.previousRowOffset = currentRowOffset;
    animationController!.addListener(() {
      _lyricPainter.offset = -animation.value;
    });
    animationController!.forward();
  }

  /// 根据当前时长获取歌词位置
  int findLyricIndexByDuration(Duration curDuration, List<Lyric> lyrics) {
    for (int i = 0; i < lyrics.length; i++) {
      if (curDuration >= lyrics[i].startTime &&
          curDuration <= lyrics[i].endTime!) {
        return i;
      }
    }
    return 0;
  }

  /// 计算传入行和第一行的偏移量
  double computeScrollY(int curLine) {
    double totalHeight = 0;
    for (var i = 0; i < curLine; i++) {
      var currPaint = widget.lyricTextPaints[i]
        ..text =
            TextSpan(text: widget.lyrics[i].lyric, style: widget.lyricStyle);
      currPaint.layout(maxWidth: widget.lyricMaxWidth!);
      totalHeight += currPaint.height + widget.lyricGap;
    }
    if (widget.remarkLyrics != null) {
      //增加 当前行之前的翻译歌词的偏移量
      widget.remarkLyrics!
          .where((subLyric) =>
              subLyric.endTime! <= widget.lyrics[curLine].endTime!)
          .toList()
          .forEach((subLyric) {
        var currentPaint = widget
            .subLyricTextPaints[widget.remarkLyrics!.indexOf(subLyric)]
          ..text = TextSpan(text: subLyric.lyric, style: widget.remarkStyle);
        currentPaint.layout(maxWidth: widget.lyricMaxWidth!);
        totalHeight += widget.remarkLyricGap + currentPaint.height;
      });
    }
    return totalHeight;
  }
}
