import 'dart:js_interop';

/// 浏览器 `console` 的类型化封装。
///
/// `package:web` 的 umbrella（`web.dart`）没有导出 `console`，这里按需补一个最小实现，
/// 避免在代码里直接调用被 lint 拦截的 `print`。
@JS('console')
external BrowserConsole get browserConsole;

extension type BrowserConsole._(JSObject _) implements JSObject {
  external void log(JSAny? data);
  external void debug(JSAny? data);
  external void info(JSAny? data);
  external void warn(JSAny? data);
  external void error(JSAny? data);
}
