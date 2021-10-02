import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:yunshu_music/component/rotate_cover_image_widget.dart';
import 'package:yunshu_music/core/lyric/lyric.dart';
import 'package:yunshu_music/core/lyric/lyric_controller.dart';
import 'package:yunshu_music/core/lyric/lyric_widget.dart';
import 'package:yunshu_music/net/model/music_entity.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/provider/play_status_model.dart';

/// 音乐播放页面
class MusicPlayPage extends StatefulWidget {
  const MusicPlayPage({Key? key}) : super(key: key);

  @override
  _MusicPlayPageState createState() => _MusicPlayPageState();
}

class _MusicPlayPageState extends State<MusicPlayPage>
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

  String _printDuration(Duration duration) {
    int seconds = duration.inSeconds;
    return '${(seconds / 60).floor()}'.padLeft(2, '0') +
        ':' +
        '${seconds % 60}'.padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('asserts/images/thz.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 100.0, sigmaY: 100.0),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            centerTitle: true,
            title: Selector<MusicDataModel, MusicDataContent?>(
              selector: (_, model) => model.getNowPlayMusic(),
              builder: (BuildContext context, value, Widget? child) {
                if (null == value) {
                  return const Text(
                    '云舒音乐',
                    style: TextStyle(fontSize: 18.0),
                    overflow: TextOverflow.ellipsis,
                  );
                } else {
                  return Column(
                    children: [
                      Text(
                        '${value.name}',
                        style: TextStyle(fontSize: 18.0),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${value.singer}',
                        style: TextStyle(fontSize: 10.0),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );
                }
              },
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          body: PageView.builder(
            itemCount: 2,
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return const _CoverPage();
              } else {
                return const _LyricPage();
              }
            },
          ),
          bottomNavigationBar: SizedBox(
            height: 112.0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  margin: const EdgeInsetsDirectional.only(
                      start: 16.0, end: 16.0, bottom: 12.0),
                  child: Flex(
                    direction: Axis.horizontal,
                    children: [
                      Expanded(
                        child: Text(
                          _printDuration(
                              context.select<PlayStatusModel, Duration>(
                                  (value) => value.position)),
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      Expanded(
                        flex: 8,
                        child: Container(
                          margin: const EdgeInsetsDirectional.only(
                              start: 6.0, end: 6.0),
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              // 轨道高度
                              trackHeight: 2,
                              // 滑块形状，可以自定义
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 4, // 滑块大小
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                // 滑块外圈形状，可以自定义
                                overlayRadius: 10, // 滑块外圈大小
                              ),
                            ),
                            child: Selector<PlayStatusModel,
                                Tuple2<double, double>>(
                              builder:
                                  (context, Tuple2<double, double> value, _) =>
                                      Slider(
                                min: 0,
                                max: value.item1,
                                onChanged: (double value) => context
                                    .read<PlayStatusModel>()
                                    .seek(
                                        Duration(milliseconds: value.toInt())),
                                value: value.item2 > value.item1
                                    ? value.item1
                                    : value.item2,
                              ),
                              selector: (_, status) => Tuple2(
                                status.duration.inMilliseconds.toDouble(),
                                status.position.inMilliseconds.toDouble(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _printDuration(
                              context.select<PlayStatusModel, Duration>(
                                  (value) => value.duration)),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      color: Colors.white,
                      iconSize: 35,
                      icon: const Icon(Icons.skip_previous_outlined),
                      onPressed: () {
                        Provider.of<MusicDataModel>(context, listen: false)
                            .toPrevious();
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
                        PlayStatusModel status = Provider.of<PlayStatusModel>(
                            context,
                            listen: false);
                        status.setPlay(!status.isPlayNow);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_outlined),
                      color: Colors.white,
                      iconSize: 35,
                      onPressed: () {
                        Provider.of<MusicDataModel>(context, listen: false)
                            .toNext();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 封面页
class _CoverPage extends StatefulWidget {
  const _CoverPage({Key? key}) : super(key: key);

  @override
  State<_CoverPage> createState() => _CoverPageState();
}

class _CoverPageState extends State<_CoverPage>
    with AutomaticKeepAliveClientMixin<_CoverPage> {
  final RotateCoverImageController _rotateCoverImageController =
      RotateCoverImageController();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    print('CoverPage build');
    return Center(
      child: Selector<PlayStatusModel, bool>(
        selector: (_, status) => status.isPlayNow,
        builder: (BuildContext context, value, Widget? child) {
          value
              ? _rotateCoverImageController.repeat()
              : _rotateCoverImageController.stop();
          return child!;
        },
        child: RotateCoverImageWidget(
          width: 225,
          height: 225,
          duration: const Duration(seconds: 20),
          name: 'asserts/images/thz.jpg',
          controller: _rotateCoverImageController,
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

/// 歌词页
class _LyricPage extends StatefulWidget {
  const _LyricPage({Key? key}) : super(key: key);

  @override
  _LyricPageState createState() => _LyricPageState();
}

class _LyricPageState extends State<_LyricPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin<_LyricPage> {
  //是否显示选择器
  bool showSelect = false;

  //歌词控制器
  late LyricController controller;

  @override
  void initState() {
    super.initState();
    controller = LyricController(vsync: this);
    //监听控制器
    controller.addListener(() {
      //如果拖动歌词则显示选择器
      if (showSelect != controller.isDragging) {
        if (mounted) {
          setState(() {
            showSelect = controller.isDragging;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: <Widget>[
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Center(
                child: Selector<MusicDataModel, List<Lyric>?>(
                    selector: (_, data) => data.lyricList,
                    builder: (_, value, __) {
                      if (null == value) {
                        return const Text(
                          '该歌曲暂无歌词',
                          style: TextStyle(color: Colors.white),
                        );
                      } else {
                        return Selector<PlayStatusModel, Duration>(
                          builder:
                              (BuildContext context, value, Widget? child) {
                            controller.progress = value;
                            return child!;
                          },
                          selector: (_, status) => status.position,
                          child: LyricWidget(
                            size: const Size(double.infinity, double.infinity),
                            lyrics: value,
                            controller: controller,
                          ),
                        );
                      }
                    }),
              ),
              Offstage(
                offstage: !showSelect,
                child: GestureDetector(
                  onTap: () {
                    //点击选择器后移动歌词到滑动位置;
                    controller.draggingComplete();
                    //当前进度
                    print("进度:${controller.draggingProgress}");
                    context
                        .read<PlayStatusModel>()
                        .seek(controller.draggingProgress);
                  },
                  child: Row(
                    children: const [
                      Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                      ),
                      Expanded(
                          child: Divider(
                        color: Colors.grey,
                      )),
                    ],
                  ),
                ),
              )
            ],
          ),
        )
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
