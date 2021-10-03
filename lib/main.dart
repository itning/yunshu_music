import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/provider/play_status_model.dart';
import 'package:yunshu_music/provider/theme_model.dart';
import 'package:yunshu_music/route/app_route_delegate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeModel.get().init();
  runApp(const YunShuMusicApp());
}

/// 主入口
class YunShuMusicApp extends StatelessWidget {
  const YunShuMusicApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeModel.get()),
        ChangeNotifierProvider(create: (_) => PlayStatusModel.get()),
        ChangeNotifierProvider(create: (_) => MusicDataModel.get()),
      ],
      child: Consumer<ThemeModel>(
        builder: (_, theme, __) {
          return MaterialApp(
            darkTheme: ThemeData.dark(),
            themeMode: theme.themeMode,
            title: '云舒音乐',
            home: Router(
              routerDelegate: AppRouterDelegate(),
              // Android实体返回键
              backButtonDispatcher: RootBackButtonDispatcher(),
            ),
          );
        },
      ),
    );
  }
}
