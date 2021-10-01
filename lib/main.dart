import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/provider/play_status_model.dart';
import 'package:yunshu_music/route/app_route_delegate.dart';

void main() => runApp(const YunShuMusicApp());

/// 主入口
class YunShuMusicApp extends StatelessWidget {
  const YunShuMusicApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PlayStatusModel(),
      child: MaterialApp(
        title: '云舒音乐',
        home: Router(
          routerDelegate: AppRouterDelegate(),
          // Android实体返回键
          backButtonDispatcher: RootBackButtonDispatcher(),
        ),
      ),
    );
  }
}
