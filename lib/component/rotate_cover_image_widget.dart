import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/component/image_fade.dart';
import 'package:yunshu_music/provider/play_status_model.dart';

/// 可旋转的封面图Widget
class RotateCoverImageWidget extends StatefulWidget {
  final double width;
  final double height;
  final String name;
  final Duration duration;

  const RotateCoverImageWidget(
      {Key? key,
      required this.width,
      required this.height,
      required this.name,
      required this.duration})
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
  }

  @override
  void dispose() {
    _coverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<PlayStatusModel, bool>(
      builder: (_, value, Widget? child) {
        value ? _coverController.repeat() : _coverController.stop();
        return child!;
      },
      selector: (_, model) => model.isPlayNow,
      child: RotationTransition(
        alignment: Alignment.center,
        turns: _coverController,
        child: ClipOval(
          child: ImageFade(
            fit: BoxFit.cover,
            width: widget.width,
            height: widget.height,
            image: Image.memory(base64Decode(widget.name)).image,
          ),
        ),
      ),
    );
  }
}
