import 'package:flutter_test/flutter_test.dart';
import 'package:yunshu_music/method_channel/music_channel.dart';

void main() {
  test('exposes app minimization through the project method channel', () async {
    await MusicChannel.get().minimizeApp();
  });
}
