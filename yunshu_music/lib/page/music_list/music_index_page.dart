import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_minimizer_plus/flutter_app_minimizer_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:yunshu_music/hotkey/action.dart';
import 'package:yunshu_music/hotkey/intent.dart';
import 'package:yunshu_music/page/music_list/component/music_list.dart';
import 'package:yunshu_music/page/music_list/component/music_mini_play_controller_widget.dart';
import 'package:yunshu_music/page/music_list/component/music_search_delegate.dart';
import 'package:yunshu_music/util/log_console.dart';

/// 音乐列表
class MusicIndexPage extends StatelessWidget {
  const MusicIndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!kIsWeb && !didPop) {
          FlutterAppMinimizerPlus.minimizeApp();
        }
      },
      child: Actions(
        actions: {
          PlayPauseIntent: PlayPauseAction(),
          PreviousIntent: PreviousAction(),
          NextIntent: NextAction(),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('云舒音乐'),
              actions: [
                IconButton(
                  tooltip: '搜索',
                  onPressed: () {
                    showSearch(
                      context: context,
                      delegate: MusicSearchDelegate(),
                    );
                  },
                  icon: const Icon(Icons.search),
                ),
                PopupMenuButton<String>(
                  tooltip: '菜单',
                  onSelected: (value) {
                    if (value == '设置') {
                      context.push('/setting');
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
        ),
      ),
    );
  }
}
