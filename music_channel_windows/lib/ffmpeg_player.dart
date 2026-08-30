import 'dart:async';

import 'package:flutter/services.dart';

class FfmpegPlayer {
  static const MethodChannel _methodChannel =
      MethodChannel('music_channel_windows/audio');
  static const EventChannel _eventChannel =
      EventChannel('music_channel_windows/audio/events');

  final StreamController<Map<Object?, Object?>> _eventsController =
      StreamController<Map<Object?, Object?>>.broadcast();
  late final StreamSubscription<dynamic> _subscription;

  double _volume = 1.0;

  FfmpegPlayer() {
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map<Object?, Object?>) {
          _eventsController.add(event);
        }
      },
      onError: (Object e) => _eventsController.addError(e),
    );
  }

  Stream<Map<Object?, Object?>> get events => _eventsController.stream;

  Stream<Duration> get onPositionChanged => events
      .where((e) => e['event'] == 'position')
      .map((e) => Duration(milliseconds: (e['positionMs'] as num).toInt()));

  Stream<bool> get onPlayerStateChanged =>
      events.where((e) => e['event'] == 'state').map((e) => e['playing'] == true);

  Stream<Duration?> get onPrepared => events
      .where((e) => e['event'] == 'prepared')
      .map((e) => e['durationMs'] == null
          ? null
          : Duration(milliseconds: (e['durationMs'] as num).toInt()));

  Stream<void> get onSeekComplete =>
      events.where((e) => e['event'] == 'seekComplete').map((_) {});

  Stream<void> get onComplete =>
      events.where((e) => e['event'] == 'complete').map((_) {});

  Stream<String> get onError => events
      .where((e) => e['event'] == 'error')
      .map((e) => e['message']?.toString() ?? 'unknown error');

  double get volume => _volume;

  Future<void> setSourceUrl(String url) =>
      _methodChannel.invokeMethod('setSource', {'url': url});

  Future<void> play(String url) =>
      _methodChannel.invokeMethod('play', {'url': url});

  Future<void> resume() => _methodChannel.invokeMethod('resume');

  Future<void> pause() => _methodChannel.invokeMethod('pause');

  Future<void> seek(Duration position) => _methodChannel
      .invokeMethod('seek', {'positionMs': position.inMilliseconds});

  Future<void> setVolume(double value) {
    _volume = value;
    return _methodChannel.invokeMethod('setVolume', {'volume': value});
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _eventsController.close();
    await _methodChannel.invokeMethod('dispose');
  }
}
