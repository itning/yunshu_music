import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_channel_ios/native_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('music_channel_ios/audio');
  const eventChannelName = 'music_channel_ios/audio/events';
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null),
  );

  Future<void> emitEvent(Map<Object?, Object?> event) async {
    final bytes = const StandardMethodCodec().encodeSuccessEnvelope(event);
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          eventChannelName,
          ByteData.view(bytes.buffer),
          (_) {},
        );
    await pumpEventQueue();
  }

  test('commands forward their arguments and track volume', () async {
    final player = NativeAudioPlayer();
    await player.setSourceUrl('https://example.com/a.mp3');
    await player.play('https://example.com/b.mp3');
    await player.resume();
    await player.pause();
    await player.seek(const Duration(seconds: 30));
    await player.initializeMediaSession();
    await player.updateNowPlaying(
      title: 'Song',
      artist: 'Artist',
      artworkUrl: 'https://example.com/cover.jpg',
      duration: const Duration(minutes: 3),
      queueIndex: 1,
      queueCount: 4,
    );
    await player.updatePlaybackOptions(shuffle: true, repeatMode: 'all');
    await player.setVolume(0.5);
    expect(calls.map((call) => call.method), [
      'setSource',
      'play',
      'resume',
      'pause',
      'seek',
      'initializeMediaSession',
      'updateNowPlaying',
      'updatePlaybackOptions',
      'setVolume',
    ]);
    expect(calls[4].arguments, {'positionMs': 30000});
    expect(calls[6].arguments, {
      'title': 'Song',
      'artist': 'Artist',
      'artworkUrl': 'https://example.com/cover.jpg',
      'durationMs': 180000,
      'queueIndex': 1,
      'queueCount': 4,
    });
    expect(calls[7].arguments, {'shuffle': true, 'repeatMode': 'all'});
    expect(calls[8].arguments, {'volume': 0.5});
    expect(player.volume, 0.5);
    await player.dispose();
  });

  test('native events map to typed player streams', () async {
    final player = NativeAudioPlayer();
    final durations = <Duration?>[];
    final positions = <Duration>[];
    final states = <bool>[];
    final errors = <String>[];
    var seeks = 0;
    var completes = 0;
    player.onPrepared.listen(durations.add);
    player.onPositionChanged.listen(positions.add);
    player.onPlayerStateChanged.listen(states.add);
    player.onError.listen(errors.add);
    player.onSeekComplete.listen((_) => seeks++);
    player.onComplete.listen((_) => completes++);
    await emitEvent({'event': 'prepared', 'durationMs': 120000});
    await emitEvent({'event': 'prepared', 'durationMs': null});
    await emitEvent({'event': 'position', 'positionMs': 30000});
    await emitEvent({'event': 'state', 'playing': true});
    await emitEvent({'event': 'seekComplete'});
    await emitEvent({'event': 'complete'});
    await emitEvent({'event': 'error', 'message': 'network unavailable'});
    expect(durations, [const Duration(minutes: 2), null]);
    expect(positions, [const Duration(seconds: 30)]);
    expect(states, [true]);
    expect(seeks, 1);
    expect(completes, 1);
    expect(errors, ['network unavailable']);
    await player.dispose();
  });
}
