import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:yunshu_music/method_channel/music_channel.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/provider/play_status_model.dart';

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
                iconSize: 30,
                icon: const Icon(Icons.format_list_numbered),
                onPressed: () => context.read<MusicDataModel>().nextPlayMode(),
              );
            } else if (playMode == 'randomly') {
              return IconButton(
                color: Colors.white,
                iconSize: 30,
                icon: const Icon(Icons.shuffle),
                onPressed: () => context.read<MusicDataModel>().nextPlayMode(),
              );
            } else {
              return IconButton(
                color: Colors.white,
                iconSize: 30,
                icon: const Icon(Icons.loop),
                onPressed: () => context.read<MusicDataModel>().nextPlayMode(),
              );
            }
          },
        ),
        IconButton(
          color: Colors.white,
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
          color: Colors.white,
          iconSize: 35,
          onPressed: () {
            Provider.of<MusicDataModel>(context, listen: false).toNext();
          },
        ),
        IconButton(
          icon: const Icon(Icons.playlist_play),
          color: Colors.white,
          iconSize: 35,
          onPressed: () {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(25))),
              isScrollControlled: true, // set this to true
              builder: (_) {
                return FutureBuilder(
                  future: MusicChannel.get().getPlayList(),
                  builder: (BuildContext context,
                      AsyncSnapshot<List<dynamic>> snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      if (snapshot.data == null) {
                        return DraggableScrollableSheet(
                          maxChildSize: 0.5,
                          expand: false,
                          builder: (_, controller) {
                            return const Center(
                              child: Text('播放列表为空'),
                            );
                          },
                        );
                      }
                      return DraggableScrollableSheet(
                        maxChildSize: 0.5,
                        expand: false,
                        builder: (_, controller) {
                          return PlayList(
                            scrollController: controller,
                            data: snapshot.data!,
                          );
                        },
                      );
                    }
                    return DraggableScrollableSheet(
                      maxChildSize: 0.5,
                      expand: false,
                      builder: (_, controller) {
                        return const Center(
                          child: Text('加载中...'),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class PlayList extends StatelessWidget {
  final ScrollController? scrollController;
  final List<dynamic> data;

  const PlayList({Key? key, this.scrollController, required this.data})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<dynamic> reversed = data.reversed.toList();
    return ListView.builder(
        controller: scrollController,
        itemCount: reversed.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return Container(
              alignment: AlignmentDirectional.center,
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: const Text('播放列表'),
            );
          }
          index -= 1;
          return Dismissible(
            key: Key(reversed[index]['mediaId']),
            onDismissed: (DismissDirection direction) {
              MusicChannel.get()
                  .delPlayListByMediaId(reversed[index]['mediaId']);
            },
            child: InkWell(
              onTap: () {
                context
                    .read<MusicDataModel>()
                    .setNowPlayMusicUseMusicId(reversed[index]['mediaId']);
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8.0, top: 8.0),
                child: Flex(
                  direction: Axis.horizontal,
                  children: [
                    Expanded(
                        flex: 2,
                        child: Text(
                          '${reversed.length - index}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        )),
                    Expanded(
                      flex: 13,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${reversed[index]['title']}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16.0),
                          ),
                          Text(
                            '${reversed[index]['subTitle']}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.0, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
  }
}
