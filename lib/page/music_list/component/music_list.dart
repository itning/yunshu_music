import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:yunshu_music/net/model/music_entity.dart';
import 'package:yunshu_music/page/music_list/component/music_list_item.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/route/app_route_delegate.dart';

class MusicList extends StatefulWidget {
  const MusicList({Key? key}) : super(key: key);

  @override
  _MusicListState createState() => _MusicListState();
}

class _MusicListState extends State<MusicList> {
  /// SnackBar消息
  void message(String? message) {
    if (null == message) {
      return;
    }
    if (!mounted) {
      print("message: $message");
      return;
    }
    final snackBar = SnackBar(content: Text(message));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  void initState() {
    super.initState();
    Provider.of<MusicDataModel>(context, listen: false)
        .refreshMusicList(needInit: true)
        .then(message)
        .onError((error, stackTrace) {
      message(error.toString());
      print(error);
      print(stackTrace);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context
          .read<MusicDataModel>()
          .refreshMusicList()
          .then(message)
          .onError((error, stackTrace) {
        message(error.toString());
        print(error);
        print(stackTrace);
      }),
      child: Selector<MusicDataModel, List<MusicDataContent>>(
          selector: (_, model) => model.musicList,
          builder: (BuildContext context, musicList, Widget? child) {
            if (musicList.isEmpty) {
              return const _InnerShimmer();
            }
            return Scrollbar(
              child: ListView.builder(
                  itemCount: musicList.length,
                  itemBuilder: (BuildContext context, int index) {
                    MusicDataContent music = musicList[index];
                    return _InnerListItem(
                      index: index,
                      name: music.name ?? '',
                      singer: music.singer ?? '',
                    );
                  }),
            );
          }),
    );
  }
}

class _InnerListItem extends StatelessWidget {
  final int index;
  final String name;
  final String singer;

  const _InnerListItem(
      {Key? key, required this.index, required this.name, required this.singer})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MusicListItem(
      index: index,
      title: name,
      subTitle: singer,
      rightButtonIcon: Icons.more_vert,
      onTap: () {
        AppRouterDelegate.of(context).push('/musicPlay');
        Provider.of<MusicDataModel>(context, listen: false)
            .setNowPlayMusic(index);
      },
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: "$name-$singer")).then(
            (_) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('复制成功'),
                  duration: Duration(seconds: 1),
                )));
      },
      rightButtonTap: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
          isScrollControlled: true, // set this to true
          builder: (_) {
            return DraggableScrollableSheet(
              maxChildSize: 0.5,
              expand: false,
              builder: (_, controller) {
                return ListView(
                  controller: controller,
                  children: [
                    Container(
                      alignment: AlignmentDirectional.center,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: const Text('更多操作'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.music_note),
                      title: SelectableText(name),
                    ),
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: SelectableText(singer),
                    ),
                    ListTile(
                      onTap: () {},
                      leading: const Icon(Icons.image),
                      title: const Text('删除封面缓存'),
                    ),
                    ListTile(
                      onTap: () {},
                      leading: const Icon(Icons.delete),
                      title: const Text('删除歌词缓存'),
                    ),
                    ListTile(
                      onTap: () {},
                      leading: const Icon(Icons.download),
                      title: const Text('下载歌曲到本地'),
                    ),
                    ListTile(
                      onTap: () {},
                      leading: const Icon(Icons.share),
                      title: const Text('分享这首歌给TA'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

/// 加载时占位图
class _InnerShimmer extends StatelessWidget {
  const _InnerShimmer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Expanded(
            child: Shimmer.fromColors(
              baseColor: Theme.of(context).dialogBackgroundColor,
              highlightColor: Theme.of(context).highlightColor,
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (_, __) => Container(
                  margin: const EdgeInsets.only(bottom: 8.0, top: 8.0),
                  child: Flex(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    direction: Axis.horizontal,
                    children: [
                      Expanded(
                        child: Container(
                          width: 16.0,
                          height: 45.0,
                          color: Colors.white,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                      ),
                      Expanded(
                        flex: 8,
                        child: Container(
                          width: double.infinity,
                          height: 45.0,
                          color: Colors.white,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                      ),
                      Expanded(
                        child: Container(
                          width: 16.0,
                          height: 45.0,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                itemCount: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
