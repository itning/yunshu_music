import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunshu_music/router/app_page.dart';

void main() {
  testWidgets('iOS pages use Cupertino routes for edge-swipe back', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (builderContext) {
            context = builderContext;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final page = buildAppPage(
      key: const ValueKey('settings'),
      child: const SizedBox.shrink(),
      useCupertinoPage: true,
    );

    expect(page, isA<CupertinoPage<void>>());
    expect(
      page.createRoute(context),
      isA<CupertinoRouteTransitionMixin<void>>(),
    );
  });
}
