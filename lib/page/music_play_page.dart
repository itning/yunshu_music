import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 音乐播放页面
class MusicPlayPage extends StatefulWidget {
  const MusicPlayPage({Key? key}) : super(key: key);

  @override
  _MusicPlayPageState createState() => _MusicPlayPageState();
}

class _MusicPlayPageState extends State<MusicPlayPage>
    with TickerProviderStateMixin {
  double nowSliderValue = 0.0;

  /// 播放暂停按钮动画控制器
  late AnimationController _playPauseController;

  /// 封面旋转动画控制器
  late AnimationController _coverController;

  @override
  void initState() {
    super.initState();
    _playPauseController = AnimationController(vsync: this)
      ..drive(Tween(begin: 0, end: 1))
      ..duration = const Duration(milliseconds: 500);

    _coverController =
        AnimationController(duration: const Duration(seconds: 20), vsync: this);
  }

  @override
  void dispose() {
    _playPauseController.dispose();
    _coverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: null,
      statusBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
    return Container(
      decoration: BoxDecoration(
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
              children: [
                const Text(
                  '童话镇',
                  style: TextStyle(fontSize: 18.0),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  '陈一发',
                  style: TextStyle(fontSize: 10.0),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              // TODO ITNING:进入歌词页面
              print('点击${DateTime.now()}');
            },
            child: Center(
              child: RotationTransition(
                alignment: Alignment.center,
                turns: _coverController,
                child: ClipOval(
                  // TODO ITNING:封面图从网络获取
                  child: Image.asset(
                    'asserts/images/thz.jpg',
                    fit: BoxFit.cover,
                    width: 225,
                    height: 225,
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: SizedBox(
            height: 112.0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  margin: EdgeInsetsDirectional.only(
                      start: 16.0, end: 16.0, bottom: 12.0),
                  child: Flex(
                    direction: Axis.horizontal,
                    children: [
                      Expanded(
                        child: Text(
                          '02:05',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      Expanded(
                        flex: 8,
                        child: Container(
                          margin:
                              EdgeInsetsDirectional.only(start: 6.0, end: 6.0),
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              // 轨道高度
                              trackHeight: 2,
                              // 滑块形状，可以自定义
                              thumbShape: RoundSliderThumbShape(
                                enabledThumbRadius: 4, // 滑块大小
                              ),
                              overlayShape: RoundSliderOverlayShape(
                                // 滑块外圈形状，可以自定义
                                overlayRadius: 10, // 滑块外圈大小
                              ),
                            ),
                            child: Slider(
                              min: 0,
                              max: 60,
                              onChanged: (double value) {
                                // TODO ITNING:组件回调
                                setState(() {
                                  nowSliderValue = value;
                                });
                              },
                              value: nowSliderValue,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '04:45',
                          style: TextStyle(color: Colors.white),
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
                      icon: Icon(Icons.skip_previous_outlined),
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
                        if (_coverController.isAnimating) {
                          _coverController.stop();
                        } else {
                          _coverController.repeat();
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.skip_next_outlined),
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
