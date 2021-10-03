import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yunshu_music/route/app_route_path.dart';

/// 路由
class AppRouterDelegate extends RouterDelegate<AppRoutePath>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<AppRoutePath> {
  @override
  GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final List<AppRoutePath> _stack = [];

  List<String> get stack => List.unmodifiable(_stack);

  static AppRouterDelegate of(BuildContext context) {
    final delegate = Router.of(context).routerDelegate;
    assert(delegate is AppRouterDelegate, 'Delegate type must match');
    return delegate as AppRouterDelegate;
  }

  void push(String newRoute) {
    _stack.add(AppRoutePath.createPage(newRoute));
    notifyListeners();
  }

  void remove(String routeName) {
    _stack.remove(AppRoutePath.createPage(routeName));
    notifyListeners();
  }

  @override
  AppRoutePath? get currentConfiguration =>
      _stack.isNotEmpty ? _stack.last : null;

  bool _onPopPage(Route<dynamic> route, dynamic result) {
    if (_stack.isNotEmpty) {
      if (_stack.last.path == route.settings.name) {
        _stack.remove(_stack.last);
        notifyListeners();
      }
    }
    return route.didPop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: [
        for (final item in _stack) item.generatePage(),
      ],
      onPopPage: _onPopPage,
    );
  }

  @override
  Future<void> setNewRoutePath(AppRoutePath configuration) {
    _stack.clear();
    _stack.add(configuration);
    return SynchronousFuture(null);
  }
}
