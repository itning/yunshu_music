import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// 浏览器 Screen Wake Lock API 的封装，用于歌词页保持屏幕常亮。
///
/// 页面切到后台时浏览器会自动释放锁，这里在页面重新可见时按需重新申请。
class ScreenWakeLock {
  ScreenWakeLock._();

  static bool _initialized = false;
  static bool _wanted = false;
  static web.WakeLockSentinel? _sentinel;

  static void init() {
    if (_initialized) {
      return;
    }
    _initialized = true;
    web.document.addEventListener('visibilitychange', (() {
      if (_wanted && web.document.visibilityState == 'visible') {
        _acquire();
      }
    }).toJS);
  }

  static Future<void> request() async {
    init();
    _wanted = true;
    await _acquire();
  }

  static Future<void> release() async {
    _wanted = false;
    final web.WakeLockSentinel? sentinel = _sentinel;
    _sentinel = null;
    if (sentinel != null) {
      try {
        await sentinel.release().toDart;
      } catch (_) {
        // 已释放或浏览器不支持，忽略。
      }
    }
  }

  static Future<void> _acquire() async {
    if (!_wanted || _sentinel != null) {
      return;
    }
    try {
      _sentinel = await web.window.navigator.wakeLock.request('screen').toDart;
    } catch (_) {
      _sentinel = null;
    }
  }
}
