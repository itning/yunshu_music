import 'package:flutter/services.dart';

enum NativeTrayAction { show, previous, next, toggle, quit }

class NativeMacosShell {
  NativeMacosShell({required this.onTrayAction}) {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const MethodChannel _channel = MethodChannel(
    'music_channel_macos/shell',
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

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'trayAction') return;
    final action = switch (call.arguments) {
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
