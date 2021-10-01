import 'package:flutter/material.dart';
import 'package:yunshu_music/component/rotate_cover_image_widget.dart';
import 'package:yunshu_music/page/music_play_page.dart';

/// 小型音乐控制器Widget
class MusicMiniPlayControllerWidget extends StatefulWidget {
  const MusicMiniPlayControllerWidget({Key? key}) : super(key: key);

  @override
  State<MusicMiniPlayControllerWidget> createState() =>
      _MusicMiniPlayControllerWidgetState();
}

class _MusicMiniPlayControllerWidgetState
    extends State<MusicMiniPlayControllerWidget> with TickerProviderStateMixin {
  /// 播放暂停按钮动画控制器
  late AnimationController _playPauseController;

  final RotateCoverImageController _rotateCoverImageController =
      RotateCoverImageController();

  @override
  void initState() {
    super.initState();
    _playPauseController = AnimationController(vsync: this)
      ..drive(Tween(begin: 0, end: 1))
      ..duration = const Duration(milliseconds: 500);
  }

  @override
  void dispose() {
    _playPauseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SizedBox(
        height: 54.0,
        child: InkWell(
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MusicPlayPage()));
          },
          child: Flex(
            direction: Axis.horizontal,
            children: [
              Expanded(
                flex: 2,
                child: Center(
                  child: RotateCoverImageWidget(
                    name: 'asserts/images/thz.jpg',
                    width: 52,
                    height: 52,
                    duration: const Duration(seconds: 20),
                    controller: _rotateCoverImageController,
                  ),
                ),
              ),
              Expanded(
                flex: 7,
                child: Text('音乐名称-音乐艺术家', overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                child: Column(
                  children: [
                    InkWell(
                      child: Container(
                        height: 54.0,
                        alignment: AlignmentDirectional.center,
                        child: AnimatedIcon(
                          icon: AnimatedIcons.play_pause,
                          progress: _playPauseController,
                          size: 35.0,
                        ),
                      ),
                      onTap: () {
                        // TODO ITNING:播放暂停按钮回调
                        if (_playPauseController.status ==
                            AnimationStatus.completed) {
                          _playPauseController.reverse();
                        } else if (_playPauseController.status ==
                            AnimationStatus.dismissed) {
                          _playPauseController.forward();
                        }

                        if (_rotateCoverImageController.isAnimating) {
                          _rotateCoverImageController.stop();
                        } else {
                          _rotateCoverImageController.repeat();
                        }
                      },
                    )
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
