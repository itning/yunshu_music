import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:music_channel/music_channel.dart' as channel;
import 'package:yunshu_music/provider/login_model.dart';
import 'package:yunshu_music/provider/music_data_model.dart';

class MusicChannel {
  static MusicChannel? _instance;

  static MusicChannel get() {
    _instance ??= MusicChannel();
    return _instance!;
  }

  static const _methodChannel = MethodChannel('yunshu.music/method_channel');

  late Stream<dynamic> playbackStateEvent;

  late Stream<dynamic> metadataEvent;

  late Stream<double> volumeEvent;

  bool supportMusicChannel() {
    return kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isIOS;
  }

  /// 播放模式变更事件（如系统媒体控件触发的随机/循环切换）
  Stream<dynamic> get playModeEvent {
    if (supportMusicChannel()) {
      return channel.playModeEvent;
    }
    return const Stream.empty();
  }

  Future<void> init() async {
    _methodChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'getMusicList':
          return MusicDataModel.get().musicList.map((e) => e.toJson()).toList();
        case 'getAuthorizationData':
          return LoginModel.get().getAuthorizationData();
        default:
      }
    });

    if (supportMusicChannel()) {
      StreamController<dynamic> playbackStateController =
          StreamController<dynamic>();
      playbackStateEvent = playbackStateController.stream;

      StreamController<dynamic> metadataEventController =
          StreamController<dynamic>();
      metadataEvent = metadataEventController.stream;

      StreamController<double> volumeEventController =
          StreamController<double>();
      volumeEvent = volumeEventController.stream;

      await channel.init(
        metadataEventController,
        playbackStateController,
        volumeEventController,
      );
    } else {
      // android平台
      EventChannel playbackStateEventChannel = const EventChannel(
        'yunshu.music/playback_state_event_channel',
      );
      playbackStateEvent = playbackStateEventChannel.receiveBroadcastStream();
      EventChannel metadataEventChannel = const EventChannel(
        'yunshu.music/metadata_event_channel',
      );
      metadataEvent = metadataEventChannel.receiveBroadcastStream();
    }
  }

  Future<void> initMethod() async {
    if (supportMusicChannel()) {
      return await channel.initMethod(
        MusicDataModel.get().musicList.map((e) => e.toJson()).toList(),
        LoginModel.get().getAuthorizationData(),
      );
    }
    await _methodChannel.invokeMethod("init");
  }

  Future<void> playFromId(String id) async {
    if (supportMusicChannel()) {
      return await channel.playFromId(id);
    }
    await _methodChannel.invokeMethod("playFromId", {'id': id});
  }

  Future<void> play() async {
    if (supportMusicChannel()) {
      return await channel.play();
    }
    await _methodChannel.invokeMethod("play");
  }

  Future<void> pause() async {
    if (supportMusicChannel()) {
      return await channel.pause();
    }
    await _methodChannel.invokeMethod("pause");
  }

  Future<void> skipToPrevious() async {
    if (supportMusicChannel()) {
      return await channel.skipToPrevious();
    }
    await _methodChannel.invokeMethod("skipToPrevious");
  }

  Future<void> skipToNext() async {
    if (supportMusicChannel()) {
      return await channel.skipToNext();
    }
    await _methodChannel.invokeMethod("skipToNext");
  }

  Future<void> seekTo(Duration position) async {
    if (supportMusicChannel()) {
      return await channel.seekTo(position);
    }
    await _methodChannel.invokeMethod('seekTo', {
      'position': position.inMilliseconds,
    });
  }

  Future<void> setPlayMode(String mode) async {
    if (supportMusicChannel()) {
      return await channel.setPlayMode(mode);
    }
    await _methodChannel.invokeMethod('setPlayMode', {'mode': mode});
  }

  Future<String> getPlayMode() async {
    if (supportMusicChannel()) {
      return await channel.getPlayMode();
    }
    return await _methodChannel.invokeMethod('getPlayMode');
  }

  Future<List<dynamic>> getPlayList() async {
    if (supportMusicChannel()) {
      return await channel.getPlayList();
    }
    // List<Map<String,String>>
    return await _methodChannel.invokeMethod('getPlayList');
  }

  Future<void> delPlayListByMediaId(String mediaId) async {
    if (supportMusicChannel()) {
      return await channel.delPlayListByMediaId(mediaId);
    }
    await _methodChannel.invokeMethod('delPlayListByMediaId', {
      'mediaId': mediaId,
    });
  }

  Future<void> clearPlayList() async {
    if (supportMusicChannel()) {
      return await channel.clearPlayList();
    }
    await _methodChannel.invokeMethod('clearPlayList');
  }

  Future<void> setVolume(double value) async {
    // 0.0 ~ 1.0
    if (supportMusicChannel()) {
      return await channel.setVolume(value);
    }
    throw UnimplementedError('android not impl set volume');
  }

  Future<void> setCover(Uint8List bytes) async {
    if (supportMusicChannel()) {
      return await channel.setCover(bytes);
    }
  }

  /// 设置屏幕常亮（歌词页展示时使用）：web 用 Screen Wake Lock，Android 用原生标志位
  Future<void> setKeepScreenOn(bool on) async {
    if (kIsWeb) {
      return channel.setKeepScreenOn(on);
    }
    if (Platform.isAndroid) {
      await _methodChannel.invokeMethod('setKeepScreenOn', {'on': on});
    }
  }

  /// 将 Android 应用移动到后台。
  Future<void> minimizeApp() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    await _methodChannel.invokeMethod('minimizeApp');
  }

  /// web 端「添加到主屏幕」是否可用
  bool get canInstallPwa => kIsWeb && channel.canInstallPwa;

  /// web 端「添加到主屏幕」可用性变化
  Stream<bool> get pwaInstallAvailability =>
      supportMusicChannel() ? channel.pwaInstallAvailability : const Stream.empty();

  /// 触发 web 端「添加到主屏幕」安装弹窗
  Future<void> promptPwaInstall() async {
    if (kIsWeb) {
      await channel.promptPwaInstall();
    }
  }

  /// Android 13+ 请求通知权限（后台播放的媒体通知需要）
  Future<void> requestNotificationPermission() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    await _methodChannel.invokeMethod('requestNotificationPermission');
  }
}
