import 'package:flutter/material.dart';
import 'package:move_to_background/move_to_background.dart';
import 'package:yunshu_music/page/music_list/component/music_list.dart';
import 'package:yunshu_music/page/music_list/component/music_mini_play_controller_widget.dart';
import 'package:yunshu_music/page/music_list/component/music_search_delegate.dart';
import 'package:yunshu_music/route/app_route_delegate.dart';
import 'package:yunshu_music/util/log_console.dart';

/// 音乐列表
class MusicIndexPage extends StatelessWidget {
  const MusicIndexPage({Key? key}) : super(key: key);

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
                if (value == '设置') {
                  AppRouterDelegate.of(context).push('/setting');
                } else {
                  LogConsole.openLogConsole(context);
                }
              },
              itemBuilder: (BuildContext context) {
                return {'设置', '日志'}.map((String choice) {
                  return PopupMenuItem<String>(
                    value: choice,
                    child: Text(choice),
                  );
                }).toList();
              },
            ),
          ],
        ),
        body: const MusicList(),
        bottomNavigationBar: const MusicMiniPlayControllerWidget(),
      ),
    );
  }
}
