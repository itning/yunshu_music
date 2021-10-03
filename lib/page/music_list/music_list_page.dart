import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:move_to_background/move_to_background.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/net/model/music_entity.dart';
import 'package:yunshu_music/page/music_list/component/music_mini_play_controller_widget.dart';
import 'package:yunshu_music/page/music_play/music_play_page.dart';
import 'package:yunshu_music/page/setting/app_setting_page.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/util/common_utils.dart';

/// 音乐列表
class MusicListPage extends StatelessWidget {
  const MusicListPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        MoveToBackground.moveTaskToBack();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('云舒音乐'),
          actions: [
            IconButton(
              onPressed: () {
                showSearch(context: context, delegate: MusicSearchDelegate());
              },
              icon: const Icon(Icons.search),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                Navigator.push(context, createRoute(const AppSettingPage()));
              },
              itemBuilder: (BuildContext context) {
                return {'设置'}.map((String choice) {
                  return PopupMenuItem<String>(
                    value: choice,
                    child: Text(choice),
                  );
                }).toList();
              },
            ),
          ],
        ),
        body: const ListPage(),
        bottomNavigationBar: const MusicMiniPlayControllerWidget(),
      ),
    );
  }
}

class MusicSearchDelegate extends SearchDelegate {
  MusicSearchDelegate() : super(searchFieldLabel: "搜索音乐与歌手");

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        tooltip: 'Clear',
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      )
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      icon: AnimatedIcon(
        icon: AnimatedIcons.menu_arrow,
        progress: transitionAnimation,
      ),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final String keyword = query;
    List<MusicDataContent> result =
        context.read<MusicDataModel>().search(keyword);
    return Scrollbar(
      child: ListView.builder(
          itemCount: result.length,
          itemBuilder: (_, int index) {
            MusicDataContent music = result[index];
            return ListTile(
              title: Text.rich(TextSpan(
                  children:
                      highlight(music.name!, search(music.name!, keyword)))),
              subtitle: Text.rich(TextSpan(
                  children: highlight(
                      music.singer!, search(music.singer!, keyword)))),
              trailing: IconButton(
                onPressed: () => _play(context, music.musicId),
                icon: const Icon(Icons.play_arrow),
              ),
            );
          }),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    List<MusicDataContent> result =
        context.read<MusicDataModel>().search(query);
    return Scrollbar(
      child: ListView.builder(
          itemCount: result.length,
          itemBuilder: (_, int index) {
            MusicDataContent music = result[index];
            return ListTile(
                title: Text(music.name!),
                subtitle: Text(music.singer!),
                trailing: IconButton(
                  onPressed: () => _play(context, music.musicId),
                  icon: const Icon(Icons.play_arrow),
                ));
          }),
    );
  }

  void _play(BuildContext context, String? musicId) {
    close(context, null);
    Navigator.push(context, createRoute(const MusicPlayPage()));
    Provider.of<MusicDataModel>(context, listen: false)
        .setNowPlayMusicUseMusicId(musicId);
  }
}

class ListPage extends StatefulWidget {
  const ListPage({Key? key}) : super(key: key);

  @override
  _ListPageState createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
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
            // TODO ITNING:性能优化
            return Scrollbar(
              child: ListView.builder(
                  itemCount: musicList.length,
                  itemBuilder: (BuildContext context, int index) {
                    return _ListItem(
                      serialNumber: index + 1,
                      title: musicList[index].name,
                      subTitle: musicList[index].singer,
                      rightButtonIcon: Icons.more_vert,
                      onTap: () {
                        Navigator.push(
                            context, createRoute(const MusicPlayPage()));
                        Provider.of<MusicDataModel>(context, listen: false)
                            .setNowPlayMusic(index);
                      },
                      onLongPress: () {
                        Clipboard.setData(ClipboardData(
                                text:
                                    "${musicList[index].name}-${musicList[index].singer}"))
                            .then((_) => ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(
                                  content: Text('复制成功'),
                                  duration: Duration(seconds: 1),
                                )));
                      },
                    );
                  }),
            );
          }),
    );
  }
}

/// 列表项
class _ListItem extends StatelessWidget {
  final int? serialNumber;
  final String? title;
  final String? subTitle;
  final IconData? rightButtonIcon;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;

  const _ListItem(
      {Key? key,
      this.serialNumber,
      this.title,
      this.subTitle,
      this.rightButtonIcon,
      this.onTap,
      this.onLongPress})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: onLongPress,
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 8.0, top: 8.0),
        child: Flex(
          direction: Axis.horizontal,
          children: [
            Expanded(
              child: Text(
                '$serialNumber',
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$title',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16.0),
                  ),
                  Text(
                    '$subTitle',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.0),
                  ),
                ],
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () {
                  // TODO ITNING:右按钮点击
                  print('右按钮点击了');
                },
                child: Container(
                  height: 46.0,
                  alignment: AlignmentDirectional.center,
                  child: Icon(rightButtonIcon),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
