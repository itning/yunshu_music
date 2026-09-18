import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_channel_macos/native_macos_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('music_channel_macos/shell');
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'isVisible' ? false : null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('configures the native shell and forwards window commands', () async {
    final shell = NativeMacosShell(onTrayAction: (_) {});

    await shell.initialize();
    await shell.setTitle('云舒音乐 - 测试歌曲');
    await shell.setMinimumSize(450, 900);
    await shell.showWindow();
    await shell.hideWindow();

    expect(calls.map((call) => call.method), [
      'initialize',
      'setTitle',
      'setMinimumSize',
      'showWindow',
      'hideWindow',
    ]);
    expect(calls[0].arguments, {
      'title': '云舒音乐',
      'minWidth': 450,
      'minHeight': 900,
    });
    expect(calls[2].arguments, {'width': 450, 'height': 900});
  });

  test(
    'syncs the tray presentation and dispatches native menu actions',
    () async {
      final actions = <NativeTrayAction>[];
      final shell = NativeMacosShell(onTrayAction: actions.add);

      await shell.updateTray(tooltip: '歌曲 - 歌手', isPlaying: true);
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'music_channel_macos/shell',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('trayAction', 'next'),
            ),
            (_) {},
          );
      await pumpEventQueue();

      expect(calls.single.method, 'updateTray');
      expect(calls.single.arguments, {
        'title': '歌曲 - 歌手',
        'tooltip': '歌曲 - 歌手',
        'isPlaying': true,
      });
      expect(actions, [NativeTrayAction.next]);
    },
  );

  test('syncs Dock menu state and dispatches Dock menu actions', () async {
    const dockChannel = MethodChannel('yunshu.music/dock_menu');
    final calls = <MethodCall>[];
    final actions = <NativeTrayAction>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(dockChannel, (call) async {
          calls.add(call);
          return null;
        });
    final shell = NativeMacosShell(onTrayAction: actions.add);

    await shell.updateDockMenu(
      title: '测试歌曲',
      artist: '测试歌手',
      isPlaying: true,
      canSkipPrevious: true,
      canSkipNext: false,
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'yunshu.music/dock_menu',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('dockMenuAction', 'toggle'),
          ),
          (_) {},
        );
    await pumpEventQueue();

    expect(calls.single.method, 'updateDockMenu');
    expect(calls.single.arguments, {
      'title': '测试歌曲',
      'artist': '测试歌手',
      'isPlaying': true,
      'canSkipPrevious': true,
      'canSkipNext': false,
    });
    expect(actions, [NativeTrayAction.toggle]);
  });

  test('ignores an unavailable Dock menu bridge', () async {
    const dockChannel = MethodChannel('yunshu.music/dock_menu');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(dockChannel, null);
    final shell = NativeMacosShell(onTrayAction: (_) {});

    await shell.updateDockMenu(
      title: '测试歌曲',
      artist: '测试歌手',
      isPlaying: false,
      canSkipPrevious: false,
      canSkipNext: false,
    );
  });
}
