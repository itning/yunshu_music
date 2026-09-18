import 'package:flutter/services.dart';

enum NativeNowPlayingCommand {
  play,
  pause,
  next,
  previous,
  toggle,
  seek,
  shuffleEnabled,
  shuffleDisabled,
  repeatLoop,
  repeatNone,
}

class NativeNowPlaying {
  NativeNowPlaying({required this.onCommand}) {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const MethodChannel _channel = MethodChannel('music_channel_macos');

  final void Function(NativeNowPlayingCommand command, Duration? position)
  onCommand;

  Future<void> initialize() => _channel.invokeMethod('initializeNowPlaying');

  Future<void> updateMetadata({
    required String title,
    required String artist,
    required String artworkUrl,
    required Duration duration,
  }) => _channel.invokeMethod('updateNowPlayingMetadata', {
    'title': title,
    'artist': artist,
    'artworkUrl': artworkUrl,
    'durationMs': duration.inMilliseconds,
  });

  Future<void> updatePlaybackState({required bool isPlaying}) => _channel
      .invokeMethod('updateNowPlayingPlaybackState', {'isPlaying': isPlaying});

  Future<void> updatePosition(Duration position) => _channel.invokeMethod(
    'updateNowPlayingPosition',
    {'positionMs': position.inMilliseconds},
  );

  Future<void> updatePlayMode({
    required bool shuffle,
    required String repeat,
  }) => _channel.invokeMethod('updateNowPlayingPlayMode', {
    'shuffle': shuffle,
    'repeat': repeat,
  });

  Future<void> clear() => _channel.invokeMethod('clearNowPlaying');

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'nowPlayingCommand') return;
    final arguments = call.arguments as Map<Object?, Object?>?;
    final command = switch (arguments?['command']) {
      'play' => NativeNowPlayingCommand.play,
      'pause' => NativeNowPlayingCommand.pause,
      'next' => NativeNowPlayingCommand.next,
      'previous' => NativeNowPlayingCommand.previous,
      'toggle' => NativeNowPlayingCommand.toggle,
      'seek' => NativeNowPlayingCommand.seek,
      'shuffleEnabled' => NativeNowPlayingCommand.shuffleEnabled,
      'shuffleDisabled' => NativeNowPlayingCommand.shuffleDisabled,
      'repeatLoop' => NativeNowPlayingCommand.repeatLoop,
      'repeatNone' => NativeNowPlayingCommand.repeatNone,
      _ => null,
    };
    if (command == null) return;
    final positionMs = arguments?['positionMs'];
    onCommand(
      command,
      positionMs is num ? Duration(milliseconds: positionMs.toInt()) : null,
    );
  }
}
