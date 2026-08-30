import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_channel_windows/ffmpeg_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('music_channel_windows/audio');
  const eventChannelName = 'music_channel_windows/audio/events';

  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  Future<void> emitEvent(Map<Object?, Object?> event) async {
    final bytes = const StandardMethodCodec().encodeSuccessEnvelope(event);
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(eventChannelName, ByteData.view(bytes.buffer), (_) {});
    await pumpEventQueue();
  }

  test('play sends url on method channel', () async {
    final player = FfmpegPlayer();
    await player.play('https://example.com/a.flac');
    expect(calls, hasLength(1));
    expect(calls.first.method, 'play');
    expect(calls.first.arguments, {'url': 'https://example.com/a.flac'});
    await player.dispose();
  });

  test('setSourceUrl/seek/setVolume map to method calls', () async {
    final player = FfmpegPlayer();
    await player.setSourceUrl('https://example.com/b.mp3');
    await player.seek(const Duration(seconds: 30));
    await player.setVolume(0.5);
    expect(calls.map((c) => c.method).toList(),
        ['setSource', 'seek', 'setVolume']);
    expect(calls[1].arguments, {'positionMs': 30000});
    expect(calls[2].arguments, {'volume': 0.5});
    expect(player.volume, 0.5);
    await player.dispose();
  });

  test('prepared event carries duration or null', () async {
    final player = FfmpegPlayer();
    final durations = <Duration?>[];
    player.onPrepared.listen(durations.add);
    await emitEvent({'event': 'prepared', 'durationMs': 123456});
    await emitEvent({'event': 'prepared', 'durationMs': null});
    expect(durations, [const Duration(milliseconds: 123456), null]);
    await player.dispose();
  });

  test('state/position/seekComplete/complete events map', () async {
    final player = FfmpegPlayer();
    final states = <bool>[];
    final positions = <Duration>[];
    var seekDone = 0;
    var complete = 0;
    player.onPlayerStateChanged.listen(states.add);
    player.onPositionChanged.listen(positions.add);
    player.onSeekComplete.listen((_) => seekDone++);
    player.onComplete.listen((_) => complete++);
    await emitEvent({'event': 'state', 'playing': true});
    await emitEvent({'event': 'state', 'playing': false});
    await emitEvent({'event': 'position', 'positionMs': 4242});
    await emitEvent({'event': 'seekComplete'});
    await emitEvent({'event': 'complete'});
    expect(states, [true, false]);
    expect(positions, [const Duration(milliseconds: 4242)]);
    expect(seekDone, 1);
    expect(complete, 1);
    await player.dispose();
  });

  test('error event carries message', () async {
    final player = FfmpegPlayer();
    final errors = <String>[];
    player.onError.listen(errors.add);
    await emitEvent({
      'event': 'error',
      'code': 'OPEN_FAILED',
      'message': 'Server returned 404',
    });
    expect(errors, ['Server returned 404']);
    await player.dispose();
  });
}
