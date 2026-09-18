import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/page/music_list/component/music_list_item.dart';
import 'package:yunshu_music/provider/music_data_model.dart';

void main() {
  testWidgets('keeps two lines within a 55 pixel list item', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<MusicDataModel>.value(
        value: MusicDataModel(),
        child: MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.25)),
              child: const SizedBox(
                height: 55,
                child: MusicListItem(
                  index: 0,
                  title: 'Title',
                  subTitle: 'Artist',
                  rightButtonIcon: Icons.more_vert,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
