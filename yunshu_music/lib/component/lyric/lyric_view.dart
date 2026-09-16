import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yunshu_music/component/lyric/lyric.dart';
import 'package:yunshu_music/component/lyric/lyric_controller.dart';
import 'package:yunshu_music/component/lyric/lyric_layout.dart';
import 'package:yunshu_music/component/lyric/lyric_parser.dart';

class LyricView extends StatefulWidget {
  final List<Lyric> lyrics;
  final LyricController controller;
  final TextStyle lyricStyle;
  final TextStyle currLyricStyle;
  final TextStyle draggingLyricStyle;
  final double lyricGap;
  final double? lyricMaxWidth;
  final bool enableDrag;
  final Size size;

  const LyricView({
    super.key,
    required this.lyrics,
    required this.controller,
    this.lyricStyle = const TextStyle(
      color: Colors.white70,
      fontSize: 16,
      fontFamily: 'LXGWWenKaiMono',
    ),
    this.currLyricStyle = const TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontFamily: 'LXGWWenKaiMono',
    ),
    this.draggingLyricStyle = const TextStyle(
      color: Colors.white70,
      fontSize: 16,
      fontFamily: 'LXGWWenKaiMono',
    ),
    this.lyricGap = 10,
    this.lyricMaxWidth,
    this.enableDrag = true,
    required this.size,
  });

  @override
  State<LyricView> createState() => _LyricViewState();
}

class _LyricViewState extends State<LyricView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0);
  Animation<double>? _scrollAnimation;

  LyricLayout? _layout;
  List<Lyric>? _layoutLyrics;
  double? _layoutMaxWidth;
  TextStyle? _layoutStyle;
  double? _layoutGap;

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 300),
        )..addListener(() {
          final animation = _scrollAnimation;
          if (animation != null) {
            _scrollOffset.value = animation.value;
          }
        });
    widget.controller.addListener(_onControllerChanged);
    widget.controller.onDraggingAutoReset = _resetDragging;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.controller.onDraggingAutoReset = null;
    widget.controller.cancelDragTimer();
    _animationController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final double? offset = widget.controller.draggingOffset;
    if (widget.controller.isDragging && offset != null) {
      _scrollOffset.value = offset;
      return;
    }
    _syncCurrentLine();
  }

  void _syncCurrentLine() {
    final LyricLayout? layout = _layout;
    if (layout == null || layout.length == 0) {
      return;
    }
    final int index = LyricParser.indexAt(
      widget.controller.position,
      widget.lyrics,
    );
    if (index == _currentIndex) {
      return;
    }
    _currentIndex = index;
    _animateTo(-layout.offsetOf(index));
  }

  void _resetDragging() {
    if (!mounted) {
      return;
    }
    final LyricLayout? layout = _layout;
    if (layout == null || widget.controller.draggingOffset == null) {
      return;
    }
    final int index = LyricParser.indexAt(
      widget.controller.position,
      widget.lyrics,
    );
    _currentIndex = index;
    _animateTo(-layout.offsetOf(index));
    widget.controller.cancelDragging();
  }

  void _animateTo(double target) {
    if (target == _scrollOffset.value) {
      return;
    }
    _scrollAnimation = Tween<double>(
      begin: _scrollOffset.value,
      end: target,
    ).animate(_animationController);
    _animationController.forward(from: 0);
  }

  LyricLayout _layoutFor(double maxWidth) {
    final bool stale =
        _layout == null ||
        !identical(_layoutLyrics, widget.lyrics) ||
        _layoutMaxWidth != maxWidth ||
        _layoutStyle != widget.lyricStyle ||
        _layoutGap != widget.lyricGap;
    if (stale) {
      _layout = LyricLayout(
        lyrics: widget.lyrics,
        style: widget.lyricStyle,
        maxWidth: maxWidth,
        lineGap: widget.lyricGap,
      );
      _layoutLyrics = widget.lyrics;
      _layoutMaxWidth = maxWidth;
      _layoutStyle = widget.lyricStyle;
      _layoutGap = widget.lyricGap;
    }
    return _layout!;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final LyricLayout? layout = _layout;
    if (layout == null || layout.length == 0) {
      return;
    }
    final double next = _scrollOffset.value + details.delta.dy;
    if (next >= 0 || next < -layout.totalOffset) {
      return;
    }
    final int line = _draggingLineFor(next + widget.lyricGap, layout);
    final Duration progress =
        widget.lyrics[line].startTime + const Duration(milliseconds: 1);
    if (widget.controller.isDragging) {
      widget.controller.updateDrag(
        offset: next,
        line: line,
        progress: progress,
      );
    } else {
      widget.controller.beginDrag(offset: next, line: line, progress: progress);
    }
  }

  int _draggingLineFor(double offset, LyricLayout layout) {
    final double normalized = offset > -1 ? 0 : offset;
    for (int i = 0; i < layout.length; i++) {
      if (normalized >= -layout.offsetOf(i)) {
        return i;
      }
    }
    return layout.length == 0 ? 0 : layout.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final double maxWidth =
        widget.lyricMaxWidth ?? MediaQuery.of(context).size.width;
    final LyricLayout layout = _layoutFor(maxWidth);
    final CustomPaint paint = CustomPaint(
      size: widget.size,
      painter: LyricPainter(
        lyrics: widget.lyrics,
        layout: layout,
        controller: widget.controller,
        scrollOffset: _scrollOffset,
        lyricStyle: widget.lyricStyle,
        currLyricStyle: widget.currLyricStyle,
        draggingLyricStyle: widget.draggingLyricStyle,
        maxWidth: maxWidth,
        repaint: Listenable.merge([widget.controller, _scrollOffset]),
      ),
    );
    if (!widget.enableDrag) {
      return paint;
    }
    return GestureDetector(
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: (_) => widget.controller.endDrag(),
      child: paint,
    );
  }
}

class LyricPainter extends CustomPainter {
  final List<Lyric> lyrics;
  final LyricLayout layout;
  final LyricController controller;
  final ValueListenable<double> scrollOffset;
  final TextStyle lyricStyle;
  final TextStyle currLyricStyle;
  final TextStyle draggingLyricStyle;
  final double maxWidth;

  LyricPainter({
    required this.lyrics,
    required this.layout,
    required this.controller,
    required this.scrollOffset,
    required this.lyricStyle,
    required this.currLyricStyle,
    required this.draggingLyricStyle,
    required this.maxWidth,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final int currentIndex = LyricParser.indexAt(controller.position, lyrics);
    final TextPainter currentPainter = _layoutLine(
      currentIndex,
      currLyricStyle,
    );
    final double currentLineHeight = currentPainter.height;

    for (int i = 0; i < lyrics.length; i++) {
      final bool isCurrent = i == currentIndex;
      final bool isDragging =
          controller.isDragging && controller.draggingLine == i;
      final TextPainter painter = isCurrent
          ? currentPainter
          : _layoutLine(i, isDragging ? draggingLyricStyle : lyricStyle);
      final double y = layout.lineTop(
        i,
        scrollOffset.value,
        size.height,
        currentLineHeight,
      );
      if (y < size.height && y > 0) {
        painter.paint(canvas, Offset((size.width - painter.width) / 2, y));
      }
    }
  }

  TextPainter _layoutLine(int index, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: lyrics[index].text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
  }

  @override
  bool shouldRepaint(covariant LyricPainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.lyrics != lyrics ||
        oldDelegate.lyricStyle != lyricStyle ||
        oldDelegate.currLyricStyle != currLyricStyle ||
        oldDelegate.draggingLyricStyle != draggingLyricStyle;
  }
}
