import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunshu_music/component/lyric/lyric.dart';
import 'package:yunshu_music/component/lyric/lyric_layout.dart';

List<Lyric> _lyrics(int count) => List.generate(
  count,
  (i) => Lyric(
    text: 'line$i',
    startTime: Duration(seconds: i),
    endTime: Duration(seconds: i + 1),
  ),
);

double _fakeMeasure(String text, TextStyle style, double maxWidth) =>
    text.length * 10.0;

void main() {
  const style = TextStyle(fontSize: 16);

  test('offsetOf 为高度前缀和（含行间距）', () {
    final layout = LyricLayout(
      lyrics: _lyrics(3),
      style: style,
      maxWidth: 300,
      lineGap: 5,
      measure: _fakeMeasure,
    );

    // 'line0' 长度 5 -> 高度 50；每行再加 gap 5
    expect(layout.length, 3);
    expect(layout.offsetOf(0), 0);
    expect(layout.offsetOf(1), 55);
    expect(layout.offsetOf(2), 110);
  });

  test('totalOffset 为倒数第二行之前的累计（不含最后一行高度）', () {
    final layout = LyricLayout(
      lyrics: _lyrics(3),
      style: style,
      maxWidth: 300,
      lineGap: 5,
      measure: _fakeMeasure,
    );

    expect(layout.totalOffset, layout.offsetOf(2));
    expect(layout.totalOffset, 110);
  });

  test('空列表安全', () {
    final layout = LyricLayout(
      lyrics: const [],
      style: style,
      maxWidth: 300,
      lineGap: 5,
      measure: _fakeMeasure,
    );

    expect(layout.length, 0);
    expect(layout.totalOffset, 0);
    expect(layout.offsetOf(0), 0);
  });

  test('单行 totalOffset 为 0', () {
    final layout = LyricLayout(
      lyrics: _lyrics(1),
      style: style,
      maxWidth: 300,
      lineGap: 5,
      measure: _fakeMeasure,
    );

    expect(layout.totalOffset, 0);
  });

  test('当前行在视口垂直居中', () {
    final layout = LyricLayout(
      lyrics: _lyrics(3),
      style: style,
      maxWidth: 300,
      lineGap: 5,
      measure: _fakeMeasure,
    );
    const double viewport = 400;
    const double currentHeight = 50;
    const int currentIndex = 2;
    final double scroll = -layout.offsetOf(currentIndex);

    expect(
      layout.lineTop(currentIndex, scroll, viewport, currentHeight),
      viewport / 2 - currentHeight / 2,
    );
  });

  test('非当前行相对当前行按偏移量排列', () {
    final layout = LyricLayout(
      lyrics: _lyrics(3),
      style: style,
      maxWidth: 300,
      lineGap: 5,
      measure: _fakeMeasure,
    );
    const double viewport = 400;
    const double currentHeight = 50;
    const int currentIndex = 2;
    final double scroll = -layout.offsetOf(currentIndex);
    final double currentTop = layout.lineTop(
      currentIndex,
      scroll,
      viewport,
      currentHeight,
    );

    expect(
      layout.lineTop(0, scroll, viewport, currentHeight),
      currentTop + layout.offsetOf(0) - layout.offsetOf(currentIndex),
    );
    expect(
      layout.lineTop(1, scroll, viewport, currentHeight),
      currentTop + layout.offsetOf(1) - layout.offsetOf(currentIndex),
    );
  });
}
