import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:music_channel_web/browser_console.dart';
import 'package:music_channel_web/media_session.dart';
import 'package:music_channel_web/music_channel_web.dart';
import 'package:music_channel_web/music_data.dart';
import 'package:music_platform_interface/encryption_tool.dart';
import 'package:music_platform_interface/music_model.dart';
import 'package:music_platform_interface/music_status.dart';
import 'package:web/web.dart' as web;

class MusicPlayer {
  final web.HTMLAudioElement _audio = web.HTMLAudioElement();

  static MusicPlayer? _instance;

  static MusicPlayer get() {
    _instance ??= MusicPlayer();
    return _instance!;
  }

  final PlaybackState _playbackState = PlaybackState();

  final MusicMetaData _metaData = MusicMetaData();

  bool _playNow = false;

  int numSecond2Millisecond(num second) {
    return (second * 1000).toInt();
  }

  MusicPlayer() {
    _listen('timeupdate', _onPositionChanged);
    _listen('durationchange', _onPositionChanged);
    // 播放完成
    _listen('ended', _onEnded);
    _listen('canplay', _onCanPlay);
    _listen('play', () => _setState(MusicStatus.playing));
    _listen('pause', () => _setState(MusicStatus.paused));
    _listen('volumechange', _onVolumeChanged);

    _listen('abort', () => _logWarn('不是因为出错而导致的媒体数据下载中止。'));
    _listen('error', () => _logWarn('媒体下载过程中错误。例如突然无网络了。或者文件地址不对。'));
    _listen('stalled', () => _logWarn('媒体数据意外地不再可用。'));

    _setState(MusicStatus.none);
    _setupMediaSession();
  }

  void _listen(String type, void Function() handler) {
    _audio.addEventListener(type, handler.toJS);
  }

  void _logWarn(String message) {
    browserConsole.warn(message.toJS);
  }

  /// 统一更新播放状态，并同步浏览器 Media Session 的 playbackState。
  void _setState(MusicStatus state) {
    _playbackState.state = state;
    MusicChannel.get().playbackStateController.sink.add(_playbackState.toMap());
    if (state == MusicStatus.playing) {
      WebMediaSession.setPlaybackState(true);
    } else if (state == MusicStatus.paused || state == MusicStatus.none) {
      WebMediaSession.setPlaybackState(false);
    }
  }

  /// 注册系统媒体控件（锁屏/通知/耳机按键）动作。
  void _setupMediaSession() {
    WebMediaSession.setActionHandler('play', onPlay);
    WebMediaSession.setActionHandler('pause', onPause);
    WebMediaSession.setActionHandler('stop', onStop);
    WebMediaSession.setActionHandler(
      'previoustrack',
      () => onSkipToPrevious(true),
    );
    WebMediaSession.setActionHandler('nexttrack', () => onSkipToNext(true));
    WebMediaSession.setActionHandlerWithDetails(
      'seekbackward',
      (details) => _seekBy(details.seekOffset?.round() ?? -10),
    );
    WebMediaSession.setActionHandlerWithDetails(
      'seekforward',
      (details) => _seekBy(details.seekOffset?.round() ?? 10),
    );
    WebMediaSession.setActionHandlerWithDetails('seekto', (details) {
      final double? seekTime = details.seekTime;
      if (seekTime != null) {
        onSeekTo(numSecond2Millisecond(seekTime));
      }
    });
  }

  void _seekBy(int offsetSeconds) {
    if (_audio.duration.isNaN) {
      return;
    }
    onSeekTo(numSecond2Millisecond(_audio.currentTime) + offsetSeconds * 1000);
  }

  void _onPositionChanged() {
    if (_audio.currentTime.isNaN || _audio.duration.isNaN) {
      return;
    }
    _playbackState.position = numSecond2Millisecond(_audio.currentTime);
    web.TimeRanges buffered = _audio.buffered;
    int length = buffered.length;
    _playbackState.bufferedPosition = numSecond2Millisecond(
      length == 0
          ? 0
          : buffered.end(length - 1) / _audio.duration * _audio.duration,
    );
    _metaData.duration = numSecond2Millisecond(_audio.duration);
    MusicChannel.get().playbackStateController.sink.add(_playbackState.toMap());
    MusicChannel.get().metadataEventController.sink.add(_metaData.toMap());
    WebMediaSession.setPositionState(
      duration: _audio.duration,
      position: _audio.currentTime,
    );
  }

  void _onVolumeChanged() {
    MusicChannel.get().volumeController.sink.add(_audio.volume);
  }

  void _onEnded() {
    browserConsole.info('onEnd'.toJS);
    _setState(MusicStatus.none);
    onSkipToNext(false);
  }

  void _onCanPlay() {
    browserConsole.info('onCanPlay'.toJS);
    if (_playNow) {
      onPlay();
    } else {
      _setState(MusicStatus.paused);
      _playNow = true;
    }
  }

  void onPlayFromMediaId(String mediaId) {
    MusicData.get().playFromMusicId(mediaId);
    initPlay();
  }

  void onPlay() {
    browserConsole.info('onPlay'.toJS);
    _audio.play().toDart.then(
      (_) => _setState(MusicStatus.playing),
      onError: (Object error) {
        // 浏览器自动播放策略拦截时会走到这里，此时并未真正播放。
        browserConsole.error('$error'.toJS);
        _setState(MusicStatus.paused);
      },
    );
  }

  void onPause() {
    browserConsole.info('onPause'.toJS);
    _audio.pause();
    _setState(MusicStatus.paused);
  }

  void onStop() {
    browserConsole.info('onStop'.toJS);
    _audio.pause();
    _setState(MusicStatus.none);
  }

  void onSeekTo(int position) {
    if (position < 0) {
      position = 0;
    }
    if (position > numSecond2Millisecond(_audio.duration)) {
      position = numSecond2Millisecond(_audio.duration);
    }
    _audio.currentTime = position / 1000;
  }

  void onSkipToPrevious(bool userTrigger) {
    browserConsole.info('onSkipToPrevious'.toJS);
    _setState(MusicStatus.skippingToPrevious);
    MusicData.get().previous(userTrigger);
    initPlay();
  }

  void onSkipToNext(bool userTrigger) {
    browserConsole.info('onSkipToNext'.toJS);
    _setState(MusicStatus.skippingToNext);
    MusicData.get().next(userTrigger);
    initPlay();
  }

  void initPlay() {
    browserConsole.info('initPlay'.toJS);
    Music? nowPlayMusic = MusicData.get().nowPlayMusic;
    if (nowPlayMusic == null) {
      browserConsole.info('nowPlayMusic == null'.toJS);
      return;
    }
    if (nowPlayMusic.musicUri == null) {
      browserConsole.info('nowPlayMusic.musicUri == null'.toJS);
      return;
    }

    String uri = nowPlayMusic.musicUri!;
    String coverUri = nowPlayMusic.coverUri ?? '';
    if (MusicChannel.get().authorizationData["ENABLE"]) {
      uri = sign(
        url: nowPlayMusic.musicUri!,
        pkey: MusicChannel.get().authorizationData['SIGN'],
        signParamName: MusicChannel.get().authorizationData['SIGN_PARAM'],
        timeParamName: MusicChannel.get().authorizationData['TIME_PARAM'],
      );
      if (coverUri.isNotEmpty) {
        coverUri = sign(
          url: coverUri,
          pkey: MusicChannel.get().authorizationData['SIGN'],
          signParamName: MusicChannel.get().authorizationData['SIGN_PARAM'],
          timeParamName: MusicChannel.get().authorizationData['TIME_PARAM'],
        );
      }
    }
    _audio.src = uri;
    _setState(MusicStatus.connecting);
    _metaData.from(nowPlayMusic);
    MusicChannel.get().metadataEventController.sink.add(_metaData.toMap());
    WebMediaSession.setMetadata(
      title: _metaData.title,
      artist: _metaData.subTitle,
      coverUri: coverUri,
    );
    SystemChrome.setApplicationSwitcherDescription(
      ApplicationSwitcherDescription(
        label: '${_metaData.title}-${_metaData.subTitle}',
      ),
    );
    _audio.load();
    _audio.pause();
  }

  void setVolume(double value) {
    _audio.volume = value;
  }
}
