import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/provider/play_status_model.dart';
import 'package:yunshu_music/util/common_utils.dart';

class PlayerPageController extends StatelessWidget {
  const PlayerPageController({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Selector<MusicDataModel, String>(
          selector: (_, model) => model.playMode,
          builder: (context, playMode, _) {
            if (playMode == 'sequence') {
              return IconButton(
                color: Colors.white,
                tooltip: '列表循环',
                iconSize: 30,
                icon: const Icon(Icons.format_list_numbered),
                onPressed: () => context.read<MusicDataModel>().nextPlayMode(),
              );
            } else if (playMode == 'randomly') {
              return IconButton(
                color: Colors.white,
                tooltip: '随机播放',
                iconSize: 30,
                icon: const Icon(Icons.shuffle),
                onPressed: () => context.read<MusicDataModel>().nextPlayMode(),
              );
            } else {
              return IconButton(
                color: Colors.white,
                tooltip: '单曲循环',
                iconSize: 30,
                icon: const Icon(Icons.loop),
                onPressed: () => context.read<MusicDataModel>().nextPlayMode(),
              );
            }
          },
        ),
        IconButton(
          color: Colors.white,
          tooltip: '上一曲',
          iconSize: 35,
          icon: const Icon(Icons.skip_previous_outlined),
          onPressed: () {
            Provider.of<MusicDataModel>(context, listen: false).toPrevious();
          },
        ),
        Selector<PlayStatusModel, Tuple2<bool, bool>>(
          selector: (_, status) =>
              Tuple2(status.isPlayNow, status.processingState),
          builder: (BuildContext context, status, Widget? child) {
            if (status.item2) {
              return Container(
                margin: const EdgeInsets.all(16.0),
                child: const SizedBox(
                  width: 19.0,
                  height: 19.0,
                  child: CircularProgressIndicator(
                    backgroundColor: Colors.grey,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              );
            }
            return status.item1
                ? IconButton(
                    color: Colors.white,
                    tooltip: '暂停',
                    iconSize: 35,
                    icon: const Icon(Icons.pause),
                    onPressed: () {
                      PlayStatusModel playStatusModel =
                          context.read<PlayStatusModel>();
                      playStatusModel.setPlay(false);
                    },
                  )
                : IconButton(
                    color: Colors.white,
                    tooltip: '播放',
                    iconSize: 35,
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () {
                      PlayStatusModel playStatusModel =
                          context.read<PlayStatusModel>();
                      playStatusModel.setPlay(true);
                    },
                  );
          },
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_outlined),
          tooltip: '下一曲',
          color: Colors.white,
          iconSize: 35,
          onPressed: () {
            Provider.of<MusicDataModel>(context, listen: false).toNext();
          },
        ),
        IconButton(
          icon: const Icon(Icons.playlist_play),
          tooltip: '播放列表',
          color: Colors.white,
          iconSize: 35,
          onPressed: () => showPlayList(context),
        ),
      ],
    );
  }
}
