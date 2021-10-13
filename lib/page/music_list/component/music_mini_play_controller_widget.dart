import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:yunshu_music/component/rotate_cover_image_widget.dart';
import 'package:yunshu_music/net/model/music_entity.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/provider/play_status_model.dart';
import 'package:yunshu_music/route/app_route_delegate.dart';

/// 小型音乐控制器Widget
class MusicMiniPlayControllerWidget extends StatelessWidget {
  const MusicMiniPlayControllerWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Ink(
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
        height: 60.0,
        child: InkWell(
          onTap: () => AppRouterDelegate.of(context).push('/musicPlay'),
          child: Column(
            children: [
              Flex(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                direction: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                    child: Selector<MusicDataModel, Uint8List?>(
                      selector: (_, model) => model.coverBase64,
                      builder: (_, value, __) {
                        if (value == null) {
                          return RotateCoverImageWidget(
                            image:
                                Image.asset('asserts/images/default_cover.jpg')
                                    .image,
                            width: 52,
                            height: 52,
                            duration: const Duration(seconds: 20),
                          );
                        } else {
                          return RotateCoverImageWidget(
                            image: Image.memory(value).image,
                            width: 52,
                            height: 52,
                            duration: const Duration(seconds: 20),
                          );
                        }
                      },
                    ),
                  ),
                  Expanded(
                    flex: 6,
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
                    flex: 3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Selector<PlayStatusModel, Tuple2<bool, bool>>(
                          selector: (_, status) =>
                              Tuple2(status.isPlayNow, status.processingState),
                          builder: (context, status, __) {
                            if (status.item2) {
                              return Container(
                                margin: const EdgeInsets.all(16.0),
                                child: const SizedBox(
                                  width: 15.0,
                                  height: 15.0,
                                  child: CircularProgressIndicator(
                                    backgroundColor: Colors.white,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.black),
                                  ),
                                ),
                              );
                            }
                            return status.item1
                                ? IconButton(
                                    icon: const Icon(Icons.pause),
                                    onPressed: () {
                                      PlayStatusModel playStatusModel =
                                          context.read<PlayStatusModel>();
                                      playStatusModel.setPlay(false);
                                    },
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.play_arrow),
                                    onPressed: () {
                                      PlayStatusModel playStatusModel =
                                          context.read<PlayStatusModel>();
                                      playStatusModel.setPlay(true);
                                    },
                                  );
                          },
                        ),
                        Selector<MusicDataModel, String>(
                          selector: (_, model) => model.playMode,
                          builder: (context, playMode, _) {
                            if (playMode == 'sequence') {
                              return IconButton(
                                tooltip: '顺序播放',
                                icon: const Icon(Icons.format_list_numbered),
                                onPressed: () => context
                                    .read<MusicDataModel>()
                                    .nextPlayMode(),
                              );
                            } else if (playMode == 'randomly') {
                              return IconButton(
                                tooltip: '随机播放',
                                icon: const Icon(Icons.shuffle),
                                onPressed: () => context
                                    .read<MusicDataModel>()
                                    .nextPlayMode(),
                              );
                            } else {
                              return IconButton(
                                tooltip: '单曲循环',
                                icon: const Icon(Icons.loop),
                                onPressed: () => context
                                    .read<MusicDataModel>()
                                    .nextPlayMode(),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  )
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6.0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
