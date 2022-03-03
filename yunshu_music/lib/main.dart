import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yunshu_music/method_channel/music_channel.dart';
import 'package:yunshu_music/provider/cache_model.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/provider/play_status_model.dart';
import 'package:yunshu_music/provider/theme_model.dart';
import 'package:yunshu_music/route/app_route_delegate.dart';
import 'package:yunshu_music/route/app_route_parser.dart';
import 'package:yunshu_music/util/common_utils.dart';

void main() async {
  void reportErrorAndLog(FlutterErrorDetails details) {
    final errorMsg = {
      "exception": details.exceptionAsString(),
      "stackTrace": details.stack.toString(),
    };
    // 上报错误
    LogHelper.get().error("reportErrorAndLog : $errorMsg");
  }

  FlutterErrorDetails makeDetails(Object error, StackTrace stackTrace) {
    // 构建错误信息
    return FlutterErrorDetails(stack: stackTrace, exception: error);
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    // 获取 widget build 过程中出现的异常错误
    reportErrorAndLog(details);
  };

  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
  await CacheModel.get().init(sharedPreferences);
  await ThemeModel.get().init(sharedPreferences);
  await MusicChannel.get().init(sharedPreferences);
  await MusicDataModel.get().init();
  runZonedGuarded(
    () {
      runApp(const YunShuMusicApp());
    },
    (error, stackTrace) {
      // 没被我们catch的异常
      reportErrorAndLog(makeDetails(error, stackTrace));
    },
  );
  if (!kIsWeb && Platform.isAndroid) {
    // 沉浸式状态栏
    // 写在组件渲染之后，是为了在渲染后进行设置赋值，覆盖状态栏，写在渲染之前对MaterialApp组件会覆盖这个值。
    SystemUiOverlayStyle systemUiOverlayStyle =
        const SystemUiOverlayStyle(statusBarColor: Colors.transparent);
    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
  }
}

/// 主入口
class YunShuMusicApp extends StatefulWidget {
  const YunShuMusicApp({Key? key}) : super(key: key);

  @override
  State<YunShuMusicApp> createState() => _YunShuMusicAppState();
}

class _YunShuMusicAppState extends State<YunShuMusicApp> {
  final delegate = AppRouterDelegate();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeModel.get()),
        ChangeNotifierProvider(create: (_) => CacheModel.get()),
        ChangeNotifierProvider(create: (_) => PlayStatusModel.get()),
        ChangeNotifierProvider(create: (_) => MusicDataModel.get()),
      ],
      child: Consumer<ThemeModel>(
        builder: (_, theme, __) {
          return MaterialApp.router(
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale.fromSubtags(languageCode: 'zh')],
            // 与 ThemeData.dark() 相同
            darkTheme: ThemeData(
                brightness: Brightness.dark, fontFamily: 'LXGWWenKaiMono'),
            themeMode: theme.themeMode,
            theme: ThemeData(fontFamily: 'LXGWWenKaiMono'),
            title: '云舒音乐',
            routeInformationParser: AppRouteParser(),
            routerDelegate: delegate,
          );
        },
      ),
    );
  }
}
