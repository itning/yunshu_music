import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/provider/play_status_model.dart';

class PlayerPageController extends StatefulWidget {
  const PlayerPageController({Key? key}) : super(key: key);

  @override
  _PlayerPageControllerState createState() => _PlayerPageControllerState();
}

class _PlayerPageControllerState extends State<PlayerPageController>
    with TickerProviderStateMixin {
  /// 播放暂停按钮动画控制器
  late AnimationController _playPauseController;

  bool fromThisPage = false;

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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconButton(
          color: Colors.white,
          iconSize: 35,
          icon: const Icon(Icons.skip_previous_outlined),
          onPressed: () {
            Provider.of<MusicDataModel>(context, listen: false).toPrevious();
          },
        ),
        IconButton(
          icon: Selector<PlayStatusModel, bool>(
            selector: (_, status) => status.isPlayNow,
            builder: (BuildContext context, value, Widget? child) {
              // 如果在播放并且播放状态改变事件不是从当前页面触发的则动画直接结束运行
              if (value && !fromThisPage) {
                value
                    ? _playPauseController.forward(from: 1)
                    : _playPauseController.reverse(from: 0);
              } else {
                value
                    ? _playPauseController.forward()
                    : _playPauseController.reverse();
              }
              return child!;
            },
            child: AnimatedIcon(
              icon: AnimatedIcons.play_pause,
              progress: _playPauseController,
              size: 35.0,
            ),
          ),
          color: Colors.white,
          iconSize: 35,
          onPressed: () {
            fromThisPage = true;
            PlayStatusModel status =
            Provider.of<PlayStatusModel>(context, listen: false);
            status.setPlay(!status.isPlayNow);
          },
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_outlined),
          color: Colors.white,
          iconSize: 35,
          onPressed: () {
            Provider.of<MusicDataModel>(context, listen: false).toNext();
          },
        ),
      ],
    );
  }
}
