import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/component/rotate_cover_image_widget.dart';
import 'package:yunshu_music/net/model/music_entity.dart';
import 'package:yunshu_music/page/music_play_page.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/provider/play_status_model.dart';

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

  bool lastPlayStatus = false;

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
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MusicPlayPage())),
          child: Flex(
            direction: Axis.horizontal,
            children: [
              Expanded(
                flex: 2,
                child: Center(
                  child: Selector<PlayStatusModel, bool>(
                    builder: (BuildContext context, value, Widget? child) {
                      value
                          ? _rotateCoverImageController.repeat()
                          : _rotateCoverImageController.stop();
                      return child!;
                    },
                    selector: (_, status) => status.isPlayNow,
                    child: RotateCoverImageWidget(
                      name: 'asserts/images/thz.jpg',
                      width: 52,
                      height: 52,
                      duration: const Duration(seconds: 20),
                      controller: _rotateCoverImageController,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 7,
                child: Selector<MusicDataModel, MusicDataContent?>(
                  selector: (_, data) => data.getNowPlayMusic(),
                  builder: (_, music, __) {
                    if (null == music) {
                      return const Text('云舒音乐',
                          overflow: TextOverflow.ellipsis);
                    }
                    return Text('${music.name}-${music.singer}',
                        overflow: TextOverflow.ellipsis);
                  },
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    InkWell(
                      child: Container(
                        height: 54.0,
                        alignment: AlignmentDirectional.center,
                        child: Selector<PlayStatusModel, bool>(
                          selector: (_, status) => status.isPlayNow,
                          builder:
                              (BuildContext context, value, Widget? child) {
                            if (lastPlayStatus != value) {
                              lastPlayStatus = value;
                              value
                                  ? _playPauseController.forward()
                                  : _playPauseController.reverse();
                            } else {
                              value
                                  ? _playPauseController.forward(from: 1)
                                  : _playPauseController.reverse(from: 0);
                            }
                            return child!;
                          },
                          child: AnimatedIcon(
                            icon: AnimatedIcons.play_pause,
                            progress: _playPauseController,
                            size: 35.0,
                          ),
                        ),
                      ),
                      onTap: () {
                        PlayStatusModel status = Provider.of<PlayStatusModel>(
                            context,
                            listen: false);
                        status.setPlay(!status.isPlayNow);
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
