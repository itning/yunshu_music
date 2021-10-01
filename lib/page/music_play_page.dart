import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:yunshu_music/component/rotate_cover_image_widget.dart';
import 'package:yunshu_music/core/lyric/lyric_controller.dart';
import 'package:yunshu_music/core/lyric/lyric_util.dart';
import 'package:yunshu_music/core/lyric/lyric_widget.dart';
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

  @override
  void initState() {
    super.initState();
    _playPauseController = AnimationController(vsync: this)
      ..drive(Tween(begin: 0, end: 1))
      ..duration = const Duration(milliseconds: 500)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          PlayStatusModel status =
              Provider.of<PlayStatusModel>(context, listen: false);
          status.setPlay(true);
        } else if (status == AnimationStatus.dismissed) {
          PlayStatusModel status =
              Provider.of<PlayStatusModel>(context, listen: false);
          status.setPlay(false);
        }
      });
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
    //  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: null,
      statusBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
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
            title: Column(
              children: const [
                Text(
                  '童话镇',
                  style: TextStyle(fontSize: 18.0),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '陈一发',
                  style: TextStyle(fontSize: 10.0),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: AnimatedIcon(
                        icon: AnimatedIcons.play_pause,
                        progress: _playPauseController,
                        size: 35.0,
                      ),
                      color: Colors.white,
                      iconSize: 35,
                      onPressed: () {
                        if (_playPauseController.status ==
                            AnimationStatus.completed) {
                          _playPauseController.reverse();
                        } else if (_playPauseController.status ==
                            AnimationStatus.dismissed) {
                          _playPauseController.forward();
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_outlined),
                      color: Colors.white,
                      iconSize: 35,
                      onPressed: () {},
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
  late PlayStatusModel playStatusModel;

  @override
  void initState() {
    super.initState();
    print('CoverPage initState');
    playStatusModel = Provider.of<PlayStatusModel>(context, listen: false);
    Provider.of<PlayStatusModel>(context, listen: false).addListener(() {
      playStatusModel.isPlayNow
          ? _rotateCoverImageController.repeat()
          : _rotateCoverImageController.stop();
    });
  }

  @override
  void dispose() {
    print('CoverPage dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    print('CoverPage build');
    return Center(
      child: RotateCoverImageWidget(
        width: 225,
        height: 225,
        duration: const Duration(seconds: 20),
        name: 'asserts/images/thz.jpg',
        controller: _rotateCoverImageController,
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
  //歌词
  var songLyc =
      "[00:00.000] 作曲 : Maynard Plant/Blaise Plant/菊池拓哉 \n[00:00.226] 作词 : Maynard Plant/Blaise Plant/菊池拓哉\n[00:00.680]明日を照らすよSunshine\n[00:03.570]窓から射し込む…扉開いて\n[00:20.920]Stop!'cause you got me thinking\n[00:22.360]that I'm a little quicker\n[00:23.520]Go!Maybe the rhythm's off,\n[00:25.100]but I will never let you\n[00:26.280]Know!I wish that you could see it for yourself.\n[00:28.560]It's not,it's not,just stop,hey y'all!やだ!\n[00:30.930]I never thought that I would take over it all.\n[00:33.420]And now I know that there's no way I could fall.\n[00:35.970]You know it's on and on and off and on,\n[00:38.210]And no one gets away.\n[00:40.300]僕の夢は何処に在るのか?\n[00:45.100]影も形も見えなくて\n[00:50.200]追いかけていた守るべきもの\n[00:54.860]There's a sunshine in my mind\n[01:02.400]明日を照らすよSunshineどこまでも続く\n[01:07.340]目の前に広がるヒカリの先へ\n[01:12.870]未来の\n[01:15.420]輝く\n[01:18.100]You know it's hard,just take a chance.\n[01:19.670]信じて\n[01:21.289]明日も晴れるかな?\n[01:32.960]ほんの些細なことに何度も躊躇ったり\n[01:37.830]誰かのその言葉いつも気にして\n[01:42.850]そんな弱い僕でも「いつか必ずきっと!」\n[01:47.800]強がり?それも負け惜しみ?\n[01:51.940]僕の夢は何だったのか\n[01:56.720]大事なことも忘れて\n[02:01.680]目の前にある守るべきもの\n[02:06.640]There's a sunshine in my mind\n[02:14.500]明日を照らすよSunshineどこまでも続く\n[02:19.000]目の前に広がるヒカリの先へ\n[02:24.670]未来のSunshine\n[02:27.200]輝くSunshine\n[02:29.900]You know it's hard,just take a chance.\n[02:31.420]信じて\n[02:33.300]明日も晴れるかな?\n[02:47.200]Rain's got me now\n[03:05.650]I guess I'm waiting for that Sunshine\n[03:09.200]Why's It only shine in my mind\n[03:15.960]I guess I'm waiting for that Sunshine\n[03:19.110]Why's It only shine in my mind\n[03:25.970]明日を照らすよSunshineどこまでも続く\n[03:30.690]目の前に広がるヒカリの先へ\n[03:36.400]未来のSunshine\n[03:38.840]輝くSunshine\n[03:41.520]You know it's hard,just take a chance.\n[03:43.200]信じて\n[03:44.829]明日も晴れるかな?\n";

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
    // TODO ITNING:从地方歌曲变了要重新读歌词
    var lyrics = LyricUtil.formatLyric(songLyc);

    return Column(
      children: <Widget>[
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Center(
                child: Selector<PlayStatusModel, Duration>(
                  builder: (BuildContext context, value, Widget? child) {
                    controller.progress = value;
                    return child!;
                  },
                  selector: (_, status) => status.position,
                  child: LyricWidget(
                    size: const Size(double.infinity, double.infinity),
                    lyrics: lyrics!,
                    controller: controller,
                  ),
                ),
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
