import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/component/lyric/lyric.dart';
import 'package:yunshu_music/component/lyric/lyric_controller.dart';
import 'package:yunshu_music/component/lyric/lyric_widget.dart';
import 'package:yunshu_music/component/volume_slider.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/provider/play_status_model.dart';
import 'package:yunshu_music/util/common_utils.dart';

/// 歌词页
class LyricPage extends StatefulWidget {
  const LyricPage({Key? key}) : super(key: key);

  @override
  _LyricPageState createState() => _LyricPageState();
}

class _LyricPageState extends State<LyricPage>
    with AutomaticKeepAliveClientMixin<LyricPage> {
  @override
  void dispose() {
    if (!kIsWeb && Platform.isAndroid) {
      FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_KEEP_SCREEN_ON);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: <Widget>[
        if (kIsWeb || !Platform.isAndroid) const VolumeSlider(),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Center(
                child: Selector<MusicDataModel, List<Lyric>?>(
                    selector: (_, data) => data.lyricList,
                    builder: (_, value, __) {
                      if (null == value || value.isEmpty) {
                        return const Text(
                          '该歌曲暂无歌词',
                          style: TextStyle(color: Colors.white),
                        );
                      } else {
                        return LyricWidget(
                          key: UniqueKey(),
                          size: const Size(double.infinity, double.infinity),
                          lyrics: value,
                          controller: context.read<LyricController>(),
                        );
                      }
                    }),
              ),
              Selector<LyricController, bool>(
                selector: (_, c) => c.isDragging,
                builder: (BuildContext context, value, _) {
                  return Offstage(
                    offstage: !value,
                    child: GestureDetector(
                      onTap: () {
                        //点击选择器后移动歌词到滑动位置;
                        context.read<LyricController>().draggingComplete();
                        //当前进度
                        LogHelper.get().debug(
                            "进度:${context.read<LyricController>().draggingProgress}");
                        context.read<PlayStatusModel>().seek(
                            context.read<LyricController>().draggingProgress);
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
                  );
                },
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
