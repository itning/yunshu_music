import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunshu_music/method_channel/music_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('invokes app minimization through the project method channel', () async {
    const methodChannel = MethodChannel('test/minimize_app');
    String? invokedMethod;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
          invokedMethod = call.method;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null),
    );

    await MusicChannel(
      methodChannel: methodChannel,
      isAndroid: true,
    ).minimizeApp();

    expect(invokedMethod, 'minimizeApp');
  });
}
