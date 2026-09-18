import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

Page<void> buildAppPage({
  required LocalKey key,
  required Widget child,
  required bool useCupertinoPage,
}) {
  if (useCupertinoPage) {
    return CupertinoPage<void>(key: key, child: child);
  }

  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}
