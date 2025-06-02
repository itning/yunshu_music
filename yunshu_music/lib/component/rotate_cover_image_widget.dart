import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/component/image_fade.dart';
import 'package:yunshu_music/provider/play_status_model.dart';

import '../provider/setting_model.dart';

/// 可旋转的封面图Widget
class RotateCoverImageWidget extends StatefulWidget {
  final double width;
  final double height;
  final ImageProvider image;
  final Duration duration;

  const RotateCoverImageWidget({
    super.key,
    required this.width,
    required this.height,
    required this.image,
    required this.duration,
  });

  @override
  State<RotateCoverImageWidget> createState() => _RotateCoverImageWidgetState();
}

class _RotateCoverImageWidgetState extends State<RotateCoverImageWidget>
    with SingleTickerProviderStateMixin {
  /// 封面旋转动画控制器
  late AnimationController _coverController;

  @override
  void initState() {
    super.initState();
    _coverController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
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
        final enableRotation = context
            .read<SettingModel>()
            .enableMusicCoverRotating;
        if (enableRotation) {
          value ? _coverController.repeat() : _coverController.stop();
        } else {
          _coverController.stop(); // 强制停止旋转
        }
        return child!;
      },
      selector: (_, model) => model.isPlayNow,
      child: RepaintBoundary(
        child: RotationTransition(
          alignment: Alignment.center,
          turns: _coverController,
          child: ClipOval(
            child: ImageFade(
              fit: BoxFit.cover,
              width: widget.width,
              height: widget.height,
              image: widget.image,
            ),
          ),
        ),
      ),
    );
  }
}
