import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';

class NativeAudioPlayer {
  static const MethodChannel _methodChannel = MethodChannel(
    'music_channel_macos/audio',
  );
  static const EventChannel _eventChannel = EventChannel(
    'music_channel_macos/audio/events',
  );

  final StreamController<Map<Object?, Object?>> _eventsController =
      StreamController<Map<Object?, Object?>>.broadcast();
  late final StreamSubscription<dynamic> _subscription;
  double _volume = 1.0;

  NativeAudioPlayer() {
    _subscription = _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map<Object?, Object?>) {
        _eventsController.add(event);
      }
    }, onError: _eventsController.addError);
  }

  Stream<Map<Object?, Object?>> get events => _eventsController.stream;
  double get volume => _volume;

  Stream<Duration> get onPositionChanged => events
      .where((event) => event['event'] == 'position')
      .map(
        (event) => Duration(milliseconds: (event['positionMs'] as num).toInt()),
      );
  Stream<bool> get onPlayerStateChanged => events
      .where((event) => event['event'] == 'state')
      .map((event) => event['playing'] == true);
  Stream<Duration?> get onPrepared => events
      .where((event) => event['event'] == 'prepared')
      .map(
        (event) => event['durationMs'] == null
            ? null
            : Duration(milliseconds: (event['durationMs'] as num).toInt()),
      );
  Stream<void> get onSeekComplete =>
      events.where((event) => event['event'] == 'seekComplete').map((_) {});
  Stream<void> get onComplete =>
      events.where((event) => event['event'] == 'complete').map((_) {});
  Stream<String> get onError => events
      .where((event) => event['event'] == 'error')
      .map((event) => event['message']?.toString() ?? 'unknown error');

  Future<void> setSourceUrl(String url) =>
      _methodChannel.invokeMethod('setSource', {'url': url});
  Future<void> play(String url) =>
      _methodChannel.invokeMethod('play', {'url': url});
  Future<void> resume() => _methodChannel.invokeMethod('resume');
  Future<void> pause() => _methodChannel.invokeMethod('pause');
  Future<void> seek(Duration position) => _methodChannel.invokeMethod('seek', {
    'positionMs': position.inMilliseconds,
  });
  Future<void> setVolume(double value) {
    _volume = value;
    return _methodChannel.invokeMethod('setVolume', {
      'volume': _toPlayerVolume(value),
    });
  }

  double _toPlayerVolume(double value) {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    if (normalized == 0) return 0;

    const minimumDb = -40.0;
    final decibels = minimumDb + normalized * -minimumDb;
    return math.pow(10, decibels / 20).toDouble();
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _eventsController.close();
    await _methodChannel.invokeMethod('dispose');
  }
}
