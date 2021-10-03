import 'package:flutter/material.dart';
import 'package:yunshu_music/page/music_list/music_list_page.dart';
import 'package:yunshu_music/route/app_route_path.dart';

/// 路由
class AppRouterDelegate extends RouterDelegate<AppRoutePath>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<AppRoutePath> {
  @override
  final GlobalKey<NavigatorState> navigatorKey;

  AppRouterDelegate() : navigatorKey = GlobalKey<NavigatorState>() {
    NavigatorHelper.get().init((widget) {
      List<MaterialPage<dynamic>> page = [..._pages];
      page.add(_generatePage(widget));
      _pages = page;
      notifyListeners();
    });
  }

  static List<MaterialPage<dynamic>> _pages = [
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
        _pages.removeLast();
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

typedef OnJumpTo = void Function(Widget widget);

class NavigatorHelper {
  static NavigatorHelper? _instance;

  static NavigatorHelper get() {
    _instance ??= NavigatorHelper._();
    return _instance!;
  }

  NavigatorHelper._();

  OnJumpTo? _onJumpTo;

  void init(OnJumpTo onJumpTo) {
    _onJumpTo = onJumpTo;
  }

  void push(Widget widget) {
    if (null != _onJumpTo) {
      _onJumpTo!(widget);
    }
  }
}
