import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yunshu_music/method_channel/music_channel.dart';
import 'package:yunshu_music/provider/login_model.dart';

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

  test('passes the loaded music list to Android during initialization', () async {
    SharedPreferences.setMockInitialValues({});
    await LoginModel.get().init(await SharedPreferences.getInstance());

    const methodChannel = MethodChannel('yunshu.music/method_channel');
    MethodCall? invocation;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
          invocation = call;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null),
    );

    await MusicChannel(isAndroid: true).initMethod();

    expect(invocation?.method, 'init');
    expect(invocation?.arguments, {
      'musicList': <Map<String, dynamic>>[],
      'autoPlay': false,
    });
  });
}
