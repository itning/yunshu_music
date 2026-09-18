import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_channel_macos/native_now_playing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('music_channel_macos');
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('publishes metadata, playback state, and position to macOS', () async {
    final nowPlaying = NativeNowPlaying(onCommand: (_, _) {});

    await nowPlaying.initialize();
    await nowPlaying.updateMetadata(
      title: '测试歌曲',
      artist: '测试歌手',
      artworkUrl: 'https://example.com/cover.jpg',
      duration: const Duration(minutes: 3),
    );
    await nowPlaying.updatePlaybackState(isPlaying: true);
    await nowPlaying.updatePosition(const Duration(seconds: 42));
    await nowPlaying.updatePlayMode(shuffle: true, repeat: 'list');
    await nowPlaying.clear();

    expect(calls.map((call) => call.method), [
      'initializeNowPlaying',
      'updateNowPlayingMetadata',
      'updateNowPlayingPlaybackState',
      'updateNowPlayingPosition',
      'updateNowPlayingPlayMode',
      'clearNowPlaying',
    ]);
    expect(calls[1].arguments, {
      'title': '测试歌曲',
      'artist': '测试歌手',
      'artworkUrl': 'https://example.com/cover.jpg',
      'durationMs': 180000,
    });
    expect(calls[2].arguments, {'isPlaying': true});
    expect(calls[3].arguments, {'positionMs': 42000});
    expect(calls[4].arguments, {'shuffle': true, 'repeat': 'list'});
  });

  test('dispatches system remote commands to its callback', () async {
    final commands = <(NativeNowPlayingCommand, Duration?)>[];
    NativeNowPlaying(
      onCommand: (command, position) => commands.add((command, position)),
    );

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'music_channel_macos',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('nowPlayingCommand', {
              'command': 'seek',
              'positionMs': 125000,
            }),
          ),
          (_) {},
        );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'music_channel_macos',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('nowPlayingCommand', {'command': 'next'}),
          ),
          (_) {},
        );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'music_channel_macos',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('nowPlayingCommand', {'command': 'shuffleEnabled'}),
          ),
          (_) {},
        );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'music_channel_macos',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('nowPlayingCommand', {'command': 'repeatLoop'}),
          ),
          (_) {},
        );
    await pumpEventQueue();

    expect(commands, [
      (NativeNowPlayingCommand.seek, const Duration(seconds: 125)),
      (NativeNowPlayingCommand.next, null),
      (NativeNowPlayingCommand.shuffleEnabled, null),
      (NativeNowPlayingCommand.repeatLoop, null),
    ]);
  });
}
