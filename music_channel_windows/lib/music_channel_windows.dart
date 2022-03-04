
import 'dart:async';

import 'package:flutter/services.dart';

class MusicChannelWindows {
  static const MethodChannel _channel = MethodChannel('music_channel_windows');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
