import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/component/lyric/lyric.dart';
import 'package:yunshu_music/component/lyric/lyric_controller.dart';
import 'package:yunshu_music/component/lyric/lyric_widget.dart';
import 'package:yunshu_music/component/lyric/lyric_painter.dart';
import 'package:yunshu_music/method_channel/music_channel.dart';
import 'package:yunshu_music/provider/play_status_model.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MusicChannel.get()
      ..metadataEvent = const Stream.empty()
      ..playbackStateEvent = const Stream.empty();
  });

  testWidgets('dispose 时移除 controller 监听器', (tester) async {
    final controller = _CountingLyricController();
    final playStatus = PlayStatusModel();
    final lyrics = [
      Lyric('第一行', startTime: Duration.zero, endTime: const Duration(hours: 1)),
      Lyric(
        '第二行',
        startTime: const Duration(hours: 1),
        endTime: const Duration(hours: 2),
      ),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PlayStatusModel>.value(value: playStatus),
          ChangeNotifierProvider<LyricController>.value(value: controller),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: LyricWidget(
              lyrics: lyrics,
              size: const Size(300, 400),
              controller: controller,
            ),
          ),
        ),
      ),
    );

    expect(controller.addCount, greaterThan(0), reason: 'initState 应注册监听器');

    await tester.pumpWidget(const SizedBox());

    expect(
      controller.removeCount,
      controller.addCount,
      reason: 'dispose 应移除 initState 注册的监听器',
    );
  });

  testWidgets('dispose 时取消 draggingTimer', (tester) async {
    final controller = LyricController();
    final playStatus = PlayStatusModel();
    final lyrics = [
      Lyric('第一行', startTime: Duration.zero, endTime: const Duration(hours: 1)),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PlayStatusModel>.value(value: playStatus),
          ChangeNotifierProvider<LyricController>.value(value: controller),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: LyricWidget(
              lyrics: lyrics,
              size: const Size(300, 400),
              controller: controller,
            ),
          ),
        ),
      ),
    );

    bool fired = false;
    controller.draggingTimer = Timer(const Duration(milliseconds: 50), () {
      fired = true;
    });

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));

    expect(fired, isFalse, reason: 'dispose 应取消未触发的 draggingTimer');
  });

  testWidgets('isDragging 为 true 但 draggingOffset 为 null 时不崩溃', (tester) async {
    final controller = LyricController();
    final playStatus = PlayStatusModel();
    final lyrics = [
      Lyric('第一行', startTime: Duration.zero, endTime: const Duration(hours: 1)),
    ];

    Widget buildTree(Size size) => MultiProvider(
      providers: [
        ChangeNotifierProvider<PlayStatusModel>.value(value: playStatus),
        ChangeNotifierProvider<LyricController>.value(value: controller),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: LyricWidget(lyrics: lyrics, size: size, controller: controller),
        ),
      ),
    );

    await tester.pumpWidget(buildTree(const Size(300, 400)));

    controller.isDragging = true;
    await tester.pumpWidget(buildTree(const Size(320, 400)));

    expect(tester.takeException(), isNull);
  });

  testWidgets('向上拖动后 draggingLine 前进', (tester) async {
    final controller = LyricController();
    final playStatus = PlayStatusModel();
    final lyrics = [
      Lyric(
        '一',
        startTime: Duration.zero,
        endTime: const Duration(seconds: 10),
      ),
      Lyric(
        '二',
        startTime: const Duration(seconds: 10),
        endTime: const Duration(seconds: 20),
      ),
      Lyric(
        '三',
        startTime: const Duration(seconds: 20),
        endTime: const Duration(seconds: 30),
      ),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PlayStatusModel>.value(value: playStatus),
          ChangeNotifierProvider<LyricController>.value(value: controller),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: LyricWidget(
              lyrics: lyrics,
              size: const Size(300, 400),
              controller: controller,
            ),
          ),
        ),
      ),
    );

    final customPaint = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is LyricPainter,
    );
    final gesture = await tester.startGesture(tester.getCenter(customPaint));
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();

    expect(controller.isDragging, isTrue);
    expect(controller.draggingLine, 1);
    expect(
      controller.draggingProgress,
      const Duration(seconds: 10, milliseconds: 1),
    );

    await gesture.up();
  });
}
