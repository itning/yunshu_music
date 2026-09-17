import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// `setActionHandler` 回调收到的动作详情（部分字段按动作可选）。
extension type MediaSessionActionDetails._(JSObject _) implements JSObject {
  /// `seekto` 的目标位置（秒）。
  external double? get seekTime;

  /// `seekbackward` / `seekforward` 的偏移量（秒，后退为负）。
  external double? get seekOffset;

  external bool? get fastSeek;
}

/// 浏览器 Media Session API 的薄封装。
///
/// 仅在 web 平台使用；在不支持该 API 的浏览器上所有调用都是 no-op。
class WebMediaSession {
  WebMediaSession._();

  static bool get _supported => web.window.navigator.has('mediaSession');

  /// 设置系统媒体控件展示的元数据（标题/歌手/封面）。
  static void setMetadata({
    required String title,
    required String artist,
    String? coverUri,
  }) {
    if (!_supported) {
      return;
    }
    web.MediaMetadataInit init = web.MediaMetadataInit(
      title: title,
      artist: artist,
    );
    if (coverUri != null && coverUri.isNotEmpty) {
      init.artwork = [web.MediaImage(src: coverUri)].toJS;
    }
    web.window.navigator.mediaSession.metadata = web.MediaMetadata(init);
  }

  /// 同步播放/暂停状态，供系统媒体控件显示。
  static void setPlaybackState(bool playing) {
    if (!_supported) {
      return;
    }
    web.window.navigator.mediaSession.playbackState = playing
        ? 'playing'
        : 'paused';
  }

  /// 更新播放进度；`duration` 非法时不下发，避免 Media Session API 抛错。
  static void setPositionState({
    required num duration,
    required num position,
    num playbackRate = 1.0,
  }) {
    if (!_supported || duration <= 0) {
      return;
    }
    web.window.navigator.mediaSession.setPositionState(
      web.MediaPositionState(
        duration: duration,
        playbackRate: playbackRate,
        position: position.clamp(0, duration),
      ),
    );
  }

  /// 注册系统媒体控件动作；不支持的动作直接忽略。
  static void setActionHandler(String action, void Function()? handler) {
    if (!_supported) {
      return;
    }
    try {
      web.window.navigator.mediaSession.setActionHandler(action, handler?.toJS);
    } catch (_) {
      // 部分浏览器不支持个别 action，忽略即可。
    }
  }

  /// 注册需要读取动作详情的系统媒体控件动作（如 `seekto` / `seekbackward`）。
  static void setActionHandlerWithDetails(
    String action,
    void Function(MediaSessionActionDetails details)? handler,
  ) {
    if (!_supported) {
      return;
    }
    try {
      web.window.navigator.mediaSession.setActionHandler(
        action,
        handler == null
            ? null
            : (MediaSessionActionDetails details) {
                handler(details);
              }.toJS,
      );
    } catch (_) {
      // 部分浏览器不支持个别 action，忽略即可。
    }
  }
}
