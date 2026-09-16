import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunshu_music/component/lyric/lyric.dart';
import 'package:yunshu_music/component/lyric/lyric_controller.dart';
import 'package:yunshu_music/component/lyric/lyric_view.dart';

List<Lyric> _lyrics(int count) => List.generate(
  count,
  (i) => Lyric(
    text: '第$i行',
    startTime: Duration(seconds: i * 10),
    endTime: i == count - 1
        ? const Duration(hours: 200)
        : Duration(seconds: (i + 1) * 10),
  ),
);

class _CountingLyricController extends LyricController {
  int addCount = 0;
  int removeCount = 0;

  @override
  void addListener(VoidCallback listener) {
    addCount++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    removeCount++;
    super.removeListener(listener);
  }
}

Widget _app(LyricController controller, {bool enableDrag = true}) {
  return MaterialApp(
    home: Scaffold(
      body: LyricView(
        lyrics: _lyrics(4),
        controller: controller,
        size: const Size(300, 400),
        enableDrag: enableDrag,
      ),
    ),
  );
}

LyricPainter _painterOf(WidgetTester tester) {
  final CustomPaint paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is LyricPainter,
    ),
  );
  return paint.painter! as LyricPainter;
}

void main() {
  testWidgets('进度变化后滚动偏移收敛到目标行', (tester) async {
    final controller = LyricController();
    await tester.pumpWidget(_app(controller));

    controller.updatePosition(const Duration(seconds: 25));
    await tester.pumpAndSettle();

    final painter = _painterOf(tester);
    expect(painter.scrollOffset.value, -painter.layout.offsetOf(2));

    controller.dispose();
  });

  testWidgets('切换行时滚动偏移经过中间值（有动画）', (tester) async {
    final controller = LyricController();
    await tester.pumpWidget(_app(controller));

    controller.updatePosition(const Duration(seconds: 25));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final painter = _painterOf(tester);
    final double target = -painter.layout.offsetOf(2);
    expect(painter.scrollOffset.value, lessThan(0));
    expect(painter.scrollOffset.value, greaterThan(target));

    await tester.pumpAndSettle();
    expect(painter.scrollOffset.value, target);

    controller.dispose();
  });

  testWidgets('dispose 时移除 controller 监听器', (tester) async {
    final controller = _CountingLyricController();
    await tester.pumpWidget(_app(controller));
    expect(controller.addCount, greaterThan(0));

    await tester.pumpWidget(const SizedBox());
    expect(controller.removeCount, controller.addCount);

    controller.dispose();
  });

  testWidgets('dispose 时取消 draggingTimer', (tester) async {
    final controller = LyricController();
    await tester.pumpWidget(_app(controller));

    bool fired = false;
    controller.draggingTimer = Timer(const Duration(milliseconds: 50), () {
      fired = true;
    });

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));

    expect(fired, isFalse);
    controller.dispose();
  });

  testWidgets('向上拖动改变 controller 拖动状态', (tester) async {
    final controller = LyricController();
    await tester.pumpWidget(_app(controller));

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter is LyricPainter,
        ),
      ),
    );
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();

    expect(controller.isDragging, isTrue);
    expect(controller.draggingLine, 1);
    expect(
      controller.draggingProgress,
      const Duration(seconds: 10, milliseconds: 1),
    );

    await gesture.up();
    controller.dispose();
  });

  testWidgets('enableDrag=false 时不响应拖动', (tester) async {
    final controller = LyricController();
    await tester.pumpWidget(_app(controller, enableDrag: false));

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter is LyricPainter,
        ),
      ),
    );
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();

    expect(controller.isDragging, isFalse);

    await gesture.up();
    controller.dispose();
  });
}
