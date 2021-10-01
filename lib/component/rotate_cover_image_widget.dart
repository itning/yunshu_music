import 'package:flutter/material.dart';

/// 可旋转的封面图Widget
class RotateCoverImageWidget extends StatefulWidget {
  final double width;
  final double height;
  final String name;
  final Duration duration;
  final RotateCoverImageController controller;

  const RotateCoverImageWidget(
      {Key? key,
      required this.width,
      required this.height,
      required this.name,
      required this.duration,
      required this.controller})
      : super(key: key);

  @override
  _RotateCoverImageWidgetState createState() => _RotateCoverImageWidgetState();
}

class _RotateCoverImageWidgetState extends State<RotateCoverImageWidget>
    with SingleTickerProviderStateMixin {
  /// 封面旋转动画控制器
  late AnimationController _coverController;

  @override
  void initState() {
    super.initState();
    _coverController =
        AnimationController(duration: widget.duration, vsync: this);
    widget.controller.repeat = () {
      if (mounted) {
        _coverController.repeat();
      }
    };
    widget.controller.stop = () {
      if (mounted) {
        _coverController.stop();
      }
    };
    widget.controller._isAnimating = () => _coverController.isAnimating;
  }

  @override
  void dispose() {
    _coverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      alignment: Alignment.center,
      turns: _coverController,
      child: ClipOval(
        // TODO ITNING:封面图从网络获取
        child: Image.asset(
          widget.name,
          fit: BoxFit.cover,
          width: widget.width,
          height: widget.height,
        ),
      ),
    );
  }
}

typedef BoolFunction = bool Function();

class RotateCoverImageController {
  late VoidCallback repeat;

  late VoidCallback stop;

  late BoolFunction _isAnimating;

  get isAnimating => _isAnimating();
}
