import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/net/model/music_entity.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/util/common_utils.dart';

class MusicSearchDelegate extends SearchDelegate {
  MusicSearchDelegate() : super(searchFieldLabel: "搜索音乐与歌手");

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        tooltip: '清空',
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
      tooltip: '返回',
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
    return _buildWidget(context, result, keyword);
  }

  @override
  Widget buildResults(BuildContext context) {
    final String keyword = query;
    List<MusicDataContent> result =
        context.read<MusicDataModel>().search(query);
    return _buildWidget(context, result, keyword);
  }

  Widget _buildWidget(
      BuildContext context, List<MusicDataContent> result, String keyword) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      }),
      child: Scrollbar(
        child: ListView.builder(
            itemCount: result.length,
            itemBuilder: (_, int index) {
              MusicDataContent music = result[index];
              return InkWell(
                onTap: () => _play(context, music.musicId),
                onLongPress: () {
                  Clipboard.setData(
                          ClipboardData(text: "${music.name}-${music.singer}"))
                      .then((_) => ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text('复制成功',
                                style: TextStyle(fontFamily: 'LXGWWenKaiMono')),
                            duration: Duration(seconds: 1),
                          )));
                },
                child: ListTile(
                  title: Text.rich(TextSpan(
                      children: highlight(
                          music.name!, search(music.name!, keyword)))),
                  subtitle: Text.rich(TextSpan(
                      children: highlight(
                          music.singer!, search(music.singer!, keyword)))),
                  trailing: IconButton(
                    tooltip: '播放',
                    onPressed: () => _play(context, music.musicId),
                    icon: const Icon(Icons.play_arrow),
                  ),
                ),
              );
            }),
      ),
    );
  }

  void _play(BuildContext context, String? musicId) {
    close(context, null);
    context.go('/musicPlay');
    Provider.of<MusicDataModel>(context, listen: false)
        .setNowPlayMusicUseMusicId(musicId);
  }
}
