import 'package:flutter/material.dart';
import 'package:yunshu_music/component/lyric/lyric.dart';

/// 测量单行歌词高度；测试可注入假实现以摆脱字体依赖。
typedef LyricTextHeight =
    double Function(String text, TextStyle style, double maxWidth);

double _defaultMeasure(String text, TextStyle style, double maxWidth) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);
  return painter.height;
}

/// 歌词行几何：行高前缀和与拖动边界。
class LyricLayout {
  final int length;
  final double lineGap;
  final List<double> _offsets;

  LyricLayout({
    required List<Lyric> lyrics,
    required TextStyle style,
    required double maxWidth,
    required this.lineGap,
    LyricTextHeight? measure,
  }) : length = lyrics.length,
       _offsets = _buildOffsets(
         lyrics,
         style,
         maxWidth,
         lineGap,
         measure ?? _defaultMeasure,
       );

  static List<double> _buildOffsets(
    List<Lyric> lyrics,
    TextStyle style,
    double maxWidth,
    double lineGap,
    LyricTextHeight measure,
  ) {
    final List<double> offsets = List<double>.filled(lyrics.length + 1, 0);
    double total = 0;
    for (int i = 0; i < lyrics.length; i++) {
      offsets[i] = total;
      total += measure(lyrics[i].text, style, maxWidth) + lineGap;
    }
    offsets[lyrics.length] = total;
    return offsets;
  }

  /// 第 index 行相对第 0 行的偏移量，O(1)。
  double offsetOf(int index) {
    if (index <= 0) {
      return 0;
    }
    if (index >= _offsets.length) {
      return _offsets.last;
    }
    return _offsets[index];
  }

  /// 拖动边界：最后一行的偏移量（不含最后一行高度）。
  double get totalOffset => length == 0 ? 0 : _offsets[length - 1];
}
