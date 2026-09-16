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
import 'package:flutter/material.dart';
import 'package:yunshu_music/component/lyric/lyric.dart';

class LyricPainter extends CustomPainter with ChangeNotifier {
  /// 歌词列表
  List<Lyric> lyrics;

  /// 翻译/音译歌词列表
  List<Lyric>? subLyrics;

  /// 字体最大宽度
  double lyricMaxWidth;

  /// 歌词间距
  double lyricGapValue;

  /// 歌词间距
  double subLyricGapValue;

  /// 通过偏移量控制歌词滑动
  double _offset = 0;

  set offset(double value) {
    _offset = value;
    notifyListeners();
  }

  double get offset => _offset;

  //歌词位置
  int _currentLyricIndex = 0;

  int get currentLyricIndex => _currentLyricIndex;

  set currentLyricIndex(int value) {
    _currentLyricIndex = value;
    notifyListeners();
  }

  /// 歌词样式
  TextStyle? lyricTextStyle;

  /// 滑动歌词样式
  TextStyle? draggingLyricTextStyle;

  /// 滑动歌词样式
  TextStyle? draggingSubLyricTextStyle;

  /// 翻译/音译歌词样式
  TextStyle? subLyricTextStyle;

  /// 当前歌词样式
  TextStyle? currLyricTextStyle;

  /// 当前翻译/音译歌词样式
  TextStyle? currSubLyricTextStyle;

  /// 滑动到的行
  int? _draggingLine;

  int? get draggingLine => _draggingLine;

  set draggingLine(int? value) {
    _draggingLine = value;
    notifyListeners();
  }

  /// 歌词画笔数组
  final List<TextPainter> lyricTextPaints;

  /// 翻译/音译歌词画笔数组
  final List<TextPainter> subLyricTextPaints;

  /// 记录每行已应用的样式，避免重复 layout
  final List<TextStyle?> _appliedLyricStyles = [];
  final List<TextStyle?> _appliedSubLyricStyles = [];

  LyricPainter(
    this.lyrics,
    this.lyricTextPaints,
    this.subLyricTextPaints, {
    this.subLyrics,
    this.lyricTextStyle,
    this.subLyricTextStyle,
    this.currLyricTextStyle,
    this.currSubLyricTextStyle,
    this.draggingLyricTextStyle,
    this.draggingSubLyricTextStyle,
    required this.lyricGapValue,
    required this.subLyricGapValue,
    required this.lyricMaxWidth,
  });

  /// 仅在样式变化时重新 layout，避免每帧重复计算
  void _layoutLyric(int index, TextStyle? style, String text) {
    if (_appliedLyricStyles.length <= index) {
      _appliedLyricStyles.addAll(
        List<TextStyle?>.filled(index + 1 - _appliedLyricStyles.length, null),
      );
    }
    if (identical(_appliedLyricStyles[index], style)) {
      return;
    }
    lyricTextPaints[index]
      ..text = TextSpan(text: text, style: style)
      ..layout(maxWidth: lyricMaxWidth);
    _appliedLyricStyles[index] = style;
  }

  /// 仅在样式变化时重新 layout，避免每帧重复计算
  void _layoutSubLyric(int index, TextStyle? style, String text) {
    if (_appliedSubLyricStyles.length <= index) {
      _appliedSubLyricStyles.addAll(
        List<TextStyle?>.filled(
          index + 1 - _appliedSubLyricStyles.length,
          null,
        ),
      );
    }
    if (identical(_appliedSubLyricStyles[index], style)) {
      return;
    }
    subLyricTextPaints[index]
      ..text = TextSpan(text: text, style: style)
      ..layout(maxWidth: lyricMaxWidth);
    _appliedSubLyricStyles[index] = style;
  }

  @override
  void paint(Canvas canvas, Size size) {
    //初始化歌词的Y坐标在正中央
    _layoutLyric(
      currentLyricIndex,
      currLyricTextStyle,
      lyrics[currentLyricIndex].lyric,
    );
    var currentLyricY =
        _offset +
        size.height / 2 -
        lyricTextPaints[currentLyricIndex].height / 2;

    //遍历歌词进行绘制
    for (int lyricIndex = 0; lyricIndex < lyrics.length; lyricIndex++) {
      var currentLyric = lyrics[lyricIndex];
      var isCurrLine = currentLyricIndex == lyricIndex;
      var isDraggingLine = _draggingLine == lyricIndex;
      _layoutLyric(
        lyricIndex,
        isCurrLine
            ? currLyricTextStyle
            : isDraggingLine
            ? draggingLyricTextStyle
            : lyricTextStyle,
        currentLyric.lyric,
      );
      var currentLyricTextPaint = lyricTextPaints[lyricIndex];
      var currentLyricHeight = currentLyricTextPaint.height;
      //仅绘制在屏幕内的歌词
      if (currentLyricY < size.height && currentLyricY > 0) {
        //绘制歌词到画布
        currentLyricTextPaint.paint(
          canvas,
          Offset((size.width - currentLyricTextPaint.width) / 2, currentLyricY),
        );
      }
      //当前歌词结束后调整下次开始绘制歌词的y坐标
      currentLyricY += currentLyricHeight + lyricGapValue;
      //如果有翻译歌词时,寻找该行歌词以后的翻译歌词
      if (subLyrics != null) {
        final subStyle = isCurrLine
            ? currSubLyricTextStyle
            : isDraggingLine
            ? draggingSubLyricTextStyle
            : subLyricTextStyle;
        for (var subIndex = 0; subIndex < subLyrics!.length; subIndex++) {
          var remarkLyric = subLyrics![subIndex];
          if (remarkLyric.startTime < currentLyric.startTime ||
              remarkLyric.endTime! > currentLyric.endTime!) {
            continue;
          }
          _layoutSubLyric(subIndex, subStyle, remarkLyric.lyric);
          var currentSubPaint = subLyricTextPaints[subIndex];
          //仅绘制在屏幕内的歌词
          if (currentLyricY < size.height && currentLyricY > 0) {
            //绘制 offset=横向居中
            currentSubPaint.paint(
              canvas,
              Offset((size.width - currentSubPaint.width) / 2, currentLyricY),
            );
          }
          //当前歌词结束后调整下次开始绘制歌词的y坐标
          currentLyricY += currentSubPaint.height + subLyricGapValue;
        }
      }
    }
  }

  @override
  bool shouldRepaint(LyricPainter oldDelegate) {
    //当歌词进度、拖动行、偏移量或样式发生变化时重新绘制
    return oldDelegate.currentLyricIndex != currentLyricIndex ||
        oldDelegate.draggingLine != draggingLine ||
        oldDelegate.offset != offset ||
        oldDelegate.lyricTextStyle != lyricTextStyle ||
        oldDelegate.subLyricTextStyle != subLyricTextStyle ||
        oldDelegate.currLyricTextStyle != currLyricTextStyle ||
        oldDelegate.currSubLyricTextStyle != currSubLyricTextStyle ||
        oldDelegate.draggingLyricTextStyle != draggingLyricTextStyle ||
        oldDelegate.draggingSubLyricTextStyle != draggingSubLyricTextStyle;
  }
}
