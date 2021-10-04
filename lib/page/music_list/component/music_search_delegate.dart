import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/net/model/music_entity.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/route/app_route_delegate.dart';
import 'package:yunshu_music/util/common_utils.dart';

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
    AppRouterDelegate.of(context).push('/musicPlay');
    Provider.of<MusicDataModel>(context, listen: false)
        .setNowPlayMusicUseMusicId(musicId);
  }
}
