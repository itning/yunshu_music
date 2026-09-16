import 'package:flutter_test/flutter_test.dart';
import 'package:yunshu_music/component/lyric/lyric_controller.dart';

void main() {
  testWidgets('updatePosition 变更时通知，重复值不通知', (tester) async {
    final controller = LyricController();
    int count = 0;
    controller.addListener(() => count++);

    controller.updatePosition(const Duration(seconds: 1));
    expect(count, 1);
    controller.updatePosition(const Duration(seconds: 1));
    expect(count, 1);

    controller.dispose();
  });

  testWidgets('beginDrag/updateDrag 设置拖动状态', (tester) async {
    final controller = LyricController();

    controller.beginDrag(
      offset: -30,
      line: 1,
      progress: const Duration(seconds: 10),
    );
    expect(controller.isDragging, isTrue);
    expect(controller.draggingOffset, -30);
    expect(controller.draggingLine, 1);
    expect(controller.draggingProgress, const Duration(seconds: 10));

    controller.updateDrag(
      offset: -60,
      line: 2,
      progress: const Duration(seconds: 20),
    );
    expect(controller.draggingOffset, -60);
    expect(controller.draggingLine, 2);

    controller.dispose();
  });

  testWidgets('endDrag 到期后回调 onDraggingAutoReset', (tester) async {
    final controller = LyricController()
      ..draggingTimerDuration = const Duration(seconds: 3);
    bool reset = false;
    controller.onDraggingAutoReset = () => reset = true;

    controller.beginDrag(offset: -30, line: 1, progress: Duration.zero);
    controller.endDrag();
    expect(reset, isFalse);

    await tester.pump(const Duration(seconds: 3));
    expect(reset, isTrue);

    controller.dispose();
  });

  testWidgets('completeDrag 跳到拖动进度并清除拖动状态', (tester) async {
    final controller = LyricController();
    controller.beginDrag(
      offset: -30,
      line: 1,
      progress: const Duration(seconds: 12),
    );

    controller.completeDrag();
    expect(controller.position, const Duration(seconds: 12));
    expect(controller.isDragging, isFalse);
    expect(controller.draggingOffset, isNull);

    controller.dispose();
  });

  testWidgets('cancelDragging 保留播放进度', (tester) async {
    final controller = LyricController();
    controller.updatePosition(const Duration(seconds: 5));
    controller.beginDrag(
      offset: -30,
      line: 1,
      progress: const Duration(seconds: 12),
    );

    controller.cancelDragging();
    expect(controller.position, const Duration(seconds: 5));
    expect(controller.isDragging, isFalse);

    controller.dispose();
  });

  testWidgets('dispose 取消未触发的回弹定时器', (tester) async {
    final controller = LyricController();
    bool reset = false;
    controller.onDraggingAutoReset = () => reset = true;
    controller.beginDrag(offset: -30, line: 1, progress: Duration.zero);
    controller.endDrag();

    controller.dispose();
    await tester.pump(const Duration(seconds: 5));
    expect(reset, isFalse);
  });

  testWidgets('completeDrag 后忽略向前跳转的旧位置回传', (tester) async {
    final controller = LyricController();
    controller.updatePosition(const Duration(seconds: 10));
    controller.beginDrag(
      offset: -30,
      line: 2,
      progress: const Duration(seconds: 30),
    );
    controller.completeDrag();
    expect(controller.position, const Duration(seconds: 30));

    controller.updatePosition(const Duration(seconds: 10));
    expect(controller.position, const Duration(seconds: 30));

    controller.updatePosition(const Duration(seconds: 30));
    expect(controller.position, const Duration(seconds: 30));

    controller.updatePosition(const Duration(seconds: 31));
    expect(controller.position, const Duration(seconds: 31));

    controller.dispose();
  });

  testWidgets('completeDrag 后忽略向后跳转的旧位置回传', (tester) async {
    final controller = LyricController();
    controller.updatePosition(const Duration(seconds: 60));
    controller.beginDrag(
      offset: -30,
      line: 1,
      progress: const Duration(seconds: 20),
    );
    controller.completeDrag();
    expect(controller.position, const Duration(seconds: 20));

    controller.updatePosition(const Duration(seconds: 61));
    expect(controller.position, const Duration(seconds: 20));

    controller.updatePosition(const Duration(seconds: 20));
    expect(controller.position, const Duration(seconds: 20));

    controller.updatePosition(const Duration(seconds: 21));
    expect(controller.position, const Duration(seconds: 21));

    controller.dispose();
  });

  testWidgets('等待超时后恢复位置更新', (tester) async {
    final controller = LyricController();
    controller.updatePosition(const Duration(seconds: 10));
    controller.beginDrag(
      offset: -30,
      line: 2,
      progress: const Duration(seconds: 30),
    );
    controller.completeDrag();

    await tester.pump(const Duration(seconds: 2));
    controller.updatePosition(const Duration(seconds: 11));
    expect(controller.position, const Duration(seconds: 11));

    controller.dispose();
  });
}
