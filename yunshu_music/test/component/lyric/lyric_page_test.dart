import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/method_channel/music_channel.dart';
import 'package:yunshu_music/page/music_play/component/lyric_page.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/provider/play_status_model.dart';
import 'package:yunshu_music/provider/volume_data_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MusicChannel.get()
      ..metadataEvent = const Stream.empty()
      ..playbackStateEvent = const Stream.empty()
      ..volumeEvent = const Stream<double>.empty();
  });

  Widget buildPage(PlayStatusModel playStatus) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PlayStatusModel>.value(value: playStatus),
        ChangeNotifierProvider<MusicDataModel>.value(value: MusicDataModel()),
        ChangeNotifierProvider<VolumeDataModel>.value(
          value: VolumeDataModel.get(),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: LyricPage())),
    );
  }

  testWidgets('无歌词时显示占位文案且不抛异常', (tester) async {
    await tester.pumpWidget(buildPage(PlayStatusModel()));

    expect(tester.takeException(), isNull);
    expect(find.text('该歌曲暂无歌词'), findsOneWidget);
  });

  testWidgets('播放进度更新不触发 build 期间 setState', (tester) async {
    final playbackController = StreamController<dynamic>.broadcast();
    MusicChannel.get().playbackStateEvent = playbackController.stream;
    final playStatus = PlayStatusModel();

    await tester.pumpWidget(buildPage(playStatus));

    playbackController.add({
      'position': 5000,
      'bufferedPosition': 0,
      'state': 3,
    });
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(playStatus.position, const Duration(seconds: 5));

    await playbackController.close();
  });
}
