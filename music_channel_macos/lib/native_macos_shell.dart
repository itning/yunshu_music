import 'package:flutter/services.dart';

enum NativeTrayAction { show, previous, next, toggle, quit }

class NativeMacosShell {
  NativeMacosShell({required this.onTrayAction}) {
    _channel.setMethodCallHandler(_handleNativeCall);
    _dockChannel.setMethodCallHandler(_handleDockMenuCall);
  }

  static const MethodChannel _channel = MethodChannel(
    'music_channel_macos/shell',
  );
  static const MethodChannel _dockChannel = MethodChannel(
    'yunshu.music/dock_menu',
  );

  final void Function(NativeTrayAction action) onTrayAction;

  Future<void> initialize() => _channel.invokeMethod('initialize', {
    'title': '云舒音乐',
    'minWidth': 450,
    'minHeight': 900,
  });

  Future<void> setTitle(String title) =>
      _channel.invokeMethod('setTitle', {'title': title});

  Future<void> setMinimumSize(double width, double height) => _channel
      .invokeMethod('setMinimumSize', {'width': width, 'height': height});

  Future<void> showWindow() => _channel.invokeMethod('showWindow');

  Future<void> hideWindow() => _channel.invokeMethod('hideWindow');

  Future<void> updateTray({
    String? title,
    required String tooltip,
    required bool isPlaying,
  }) => _channel.invokeMethod('updateTray', {
    'title': title ?? tooltip,
    'tooltip': tooltip,
    'isPlaying': isPlaying,
  });

  Future<void> updateDockMenu({
    required String title,
    required String artist,
    required bool isPlaying,
    required bool canSkipPrevious,
    required bool canSkipNext,
  }) async {
    try {
      await _dockChannel.invokeMethod('updateDockMenu', {
        'title': title,
        'artist': artist,
        'isPlaying': isPlaying,
        'canSkipPrevious': canSkipPrevious,
        'canSkipNext': canSkipNext,
      });
    } on MissingPluginException {
      // Older native hosts do not provide the optional Dock menu bridge.
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'trayAction') return;
    _dispatchAction(call.arguments);
  }

  Future<void> _handleDockMenuCall(MethodCall call) async {
    if (call.method != 'dockMenuAction') return;
    _dispatchAction(call.arguments);
  }

  void _dispatchAction(dynamic rawAction) {
    final action = switch (rawAction) {
      'show' => NativeTrayAction.show,
      'previous' => NativeTrayAction.previous,
      'next' => NativeTrayAction.next,
      'toggle' => NativeTrayAction.toggle,
      'quit' => NativeTrayAction.quit,
      _ => null,
    };
    if (action != null) onTrayAction(action);
  }
}
