import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:yunshu_music/component/rotate_cover_image_widget.dart';
import 'package:yunshu_music/net/model/music_entity.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/provider/play_status_model.dart';
import 'package:yunshu_music/util/common_utils.dart';

/// 小型音乐控制器Widget
class MusicMiniPlayControllerWidget extends StatelessWidget {
  const MusicMiniPlayControllerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Ink(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((255.0 * 0.5).round()),
            spreadRadius: 2,
            blurRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SizedBox(
        height: 60.0,
        child: InkWell(
          onTap: () => context.push('/musicPlay'),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                      child: Selector<MusicDataModel, Uint8List?>(
                        selector: (_, model) => model.coverBase64,
                        builder: (_, value, _) {
                          if (value == null) {
                            return RotateCoverImageWidget(
                              image: Image.asset(
                                'asserts/images/default_cover.jpg',
                              ).image,
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
                    Selector<MusicDataModel, MusicData?>(
                      selector: (_, data) => data.getNowPlayMusic(),
                      builder: (_, music, _) {
                        if (null == music) {
                          return const Text(
                            '云舒音乐',
                            overflow: TextOverflow.ellipsis,
                          );
                        }
                        return Expanded(
                          child: Text(
                            '${music.name}-${music.singer}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Selector<PlayStatusModel, Tuple2<bool, bool>>(
                    selector: (_, status) =>
                        Tuple2(status.isPlayNow, status.processingState),
                    builder: (context, status, _) {
                      if (status.item2) {
                        return Container(
                          margin: const EdgeInsets.all(16.0),
                          child: const SizedBox(
                            width: 15.0,
                            height: 15.0,
                            child: CircularProgressIndicator(
                              backgroundColor: Colors.white,
                              valueColor: AlwaysStoppedAnimation(Colors.black),
                            ),
                          ),
                        );
                      }
                      return status.item1
                          ? IconButton(
                              icon: const Icon(Icons.pause),
                              tooltip: '暂停',
                              onPressed: () {
                                PlayStatusModel playStatusModel = context
                                    .read<PlayStatusModel>();
                                playStatusModel.setPlay(false);
                              },
                            )
                          : IconButton(
                              icon: const Icon(Icons.play_arrow),
                              tooltip: '播放',
                              onPressed: () {
                                PlayStatusModel playStatusModel = context
                                    .read<PlayStatusModel>();
                                playStatusModel.setPlay(true);
                              },
                            );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 6.0, right: 16.0),
                    child: IconButton(
                      icon: const Icon(Icons.playlist_play),
                      tooltip: '播放列表',
                      onPressed: () => showPlayList(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
