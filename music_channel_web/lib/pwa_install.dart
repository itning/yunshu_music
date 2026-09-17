import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Chrome 的 `beforeinstallprompt` 事件（非标准，未包含在 package:web 中）。
extension type _BeforeInstallPromptEvent._(JSObject _) implements web.Event {
  external JSPromise<JSAny?> prompt();
  external JSPromise<JSAny?> get userChoice;
}

/// PWA「添加到主屏幕」安装引导的封装。
class PwaInstall {
  PwaInstall._();

  static bool _initialized = false;
  static JSObject? _deferredPrompt;
  static final StreamController<bool> _availability =
      StreamController<bool>.broadcast();

  /// 安装可用性变化（事件到达 / 已安装），供 UI 实时刷新。
  static Stream<bool> get availability => _availability.stream;

  /// 应用启动时调用，捕获安装事件。
  static void init() {
    if (_initialized) {
      return;
    }
    _initialized = true;
    web.window.addEventListener('beforeinstallprompt', ((web.Event event) {
      event.preventDefault();
      _deferredPrompt = event;
      _emit();
    }).toJS);
    web.window.addEventListener('appinstalled', ((web.Event event) {
      _deferredPrompt = null;
      _emit();
    }).toJS);
  }

  static bool get canInstall => _deferredPrompt != null;

  static Future<void> promptInstall() async {
    final JSObject? deferred = _deferredPrompt;
    if (deferred == null) {
      return;
    }
    _deferredPrompt = null;
    _emit();
    try {
      _BeforeInstallPromptEvent event = _BeforeInstallPromptEvent._(deferred);
      await event.prompt().toDart;
      await event.userChoice.toDart;
    } catch (_) {
      // 用户取消或浏览器不允许时忽略。
    }
  }

  static void _emit() {
    if (!_availability.isClosed) {
      _availability.add(canInstall);
    }
  }
}
