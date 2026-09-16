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

  testWidgets('无歌词时显示占位文案且不抛异常', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PlayStatusModel>.value(
            value: PlayStatusModel(),
          ),
          ChangeNotifierProvider<MusicDataModel>.value(value: MusicDataModel()),
          ChangeNotifierProvider<VolumeDataModel>.value(
            value: VolumeDataModel.get(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: LyricPage())),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('该歌曲暂无歌词'), findsOneWidget);
  });
}
