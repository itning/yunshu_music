import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/core/lyric/lyric.dart';
import 'package:yunshu_music/core/lyric/lyric_controller.dart';
import 'package:yunshu_music/core/lyric/lyric_widget.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/provider/play_status_model.dart';

/// 歌词页
class LyricPage extends StatefulWidget {
  const LyricPage({Key? key}) : super(key: key);

  @override
  _LyricPageState createState() => _LyricPageState();
}

class _LyricPageState extends State<LyricPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin<LyricPage> {
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
                        return LyricWidget(
                          size: const Size(double.infinity, double.infinity),
                          lyrics: value,
                          controller: controller,
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
