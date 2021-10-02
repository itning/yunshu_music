import 'package:flutter/material.dart';
import 'package:yunshu_music/page/music_list/music_list_page.dart';
import 'package:yunshu_music/route/app_route_path.dart';

/// 路由
class AppRouterDelegate extends RouterDelegate<AppRoutePath>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<AppRoutePath> {
  @override
  final GlobalKey<NavigatorState> navigatorKey;

  AppRouterDelegate() : navigatorKey = GlobalKey<NavigatorState>();

  final List<MaterialPage<dynamic>> _pages = [
    _generatePage(const MusicListPage()),
  ];

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: _pages,
      onPopPage: (route, result) {
        if (!route.didPop(result)) {
          return false;
        }
        return true;
      },
    );
  }

  @override
  Future<void> setNewRoutePath(AppRoutePath configuration) async {}

  /// 生成一个Page
  static MaterialPage _generatePage(Widget widget) {
    return MaterialPage(key: ValueKey(widget.hashCode), child: widget);
  }
}
