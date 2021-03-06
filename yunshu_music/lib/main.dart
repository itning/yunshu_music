import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yunshu_music/component/lyric/lyric_controller.dart';
import 'package:yunshu_music/method_channel/music_channel.dart';
import 'package:yunshu_music/page/login/login_page.dart';
import 'package:yunshu_music/page/music_list/music_index_page.dart';
import 'package:yunshu_music/page/music_play/music_play_page.dart';
import 'package:yunshu_music/page/setting/app_setting_page.dart';
import 'package:yunshu_music/provider/cache_model.dart';
import 'package:yunshu_music/provider/login_model.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/provider/music_list_status_model.dart';
import 'package:yunshu_music/provider/play_status_model.dart';
import 'package:yunshu_music/provider/setting_model.dart';
import 'package:yunshu_music/provider/theme_model.dart';
import 'package:yunshu_music/provider/volume_data_model.dart';
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
  await LoginModel.get().init(sharedPreferences);
  await MusicChannel.get().init();
  await MusicDataModel.get().init();
  await VolumeDataModel.get().init(sharedPreferences);
  await SettingModel.get().init(sharedPreferences);
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
  final GoRouter _router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return const MusicIndexPage();
        },
      ),
      GoRoute(
        path: '/musicPlay',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const MusicPlayPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: '/setting',
        builder: (BuildContext context, GoRouterState state) {
          return const AppSettingPage();
        },
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) {
          return const LoginPage();
        },
      ),
    ],
    redirect: (GoRouterState state) {
      if ('/login' != state.location && !LoginModel.get().isLogin()) {
        return '/login';
      }
      return null;
    },
    debugLogDiagnostics: kDebugMode,
  );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeModel.get()),
        ChangeNotifierProvider(create: (_) => CacheModel.get()),
        ChangeNotifierProvider(create: (_) => PlayStatusModel.get()),
        ChangeNotifierProvider(create: (_) => MusicDataModel.get()),
        ChangeNotifierProvider(create: (_) => VolumeDataModel.get()),
        ChangeNotifierProvider(create: (_) => SettingModel.get()),
        ChangeNotifierProvider(create: (_) => MusicListStatusModel.get()),
        ChangeNotifierProvider(create: (_) => LyricController()),
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
            routeInformationProvider: _router.routeInformationProvider,
            routeInformationParser: _router.routeInformationParser,
            routerDelegate: _router.routerDelegate,
          );
        },
      ),
    );
  }
}
