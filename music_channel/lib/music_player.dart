import 'dart:html' as html;

import 'package:music_channel/music_channel_web.dart';
import 'package:music_channel/music_data.dart';
import 'package:music_channel/music_model.dart';

class MusicPlayer {
  final html.AudioElement _audio = html.AudioElement();

  static MusicPlayer? _instance;

  static MusicPlayer get() {
    _instance ??= MusicPlayer();
    return _instance!;
  }

  final PlaybackState _playbackState = PlaybackState();

  final MetaData _metaData = MetaData();

  int numSecond2Millisecond(num second) {
    return (second * 1000).toInt();
  }

  bool _playNow = false;

  void musicChangeEventHandlers(dynamic) {
    if (!_audio.currentTime.isNaN && !_audio.duration.isNaN) {
      _playbackState.position = numSecond2Millisecond(_audio.currentTime);
      var timeRanges = _audio.buffered;
      var length = timeRanges.length;
      _playbackState.bufferedPosition = numSecond2Millisecond(length == 0
          ? 0
          : timeRanges.end(length - 1) / _audio.duration * _audio.duration);
      _metaData.duration = numSecond2Millisecond(_audio.duration);
      MusicChannelWeb.playbackStateEventChannel
          .invokeMethod('', _playbackState.toMap());
      MusicChannelWeb.metadataEventChannel.invokeMethod('', _metaData.toMap());
    }
  }

  MusicPlayer() {
    _audio.onTimeUpdate.listen(musicChangeEventHandlers);
    _audio.onDurationChange.listen(musicChangeEventHandlers);
    // 播放完成
    _audio.onEnded.listen((event) {
      html.window.console.info('onEnd');
      _playbackState.state = 0;
      MusicChannelWeb.playbackStateEventChannel
          .invokeMethod('', _playbackState.toMap());
      onSkipToNext(false);
    });

    _audio.onCanPlay.listen((event) {
      html.window.console.info('onCanPlay');
      if (_playNow) {
        onPlay();
      } else {
        _playbackState.state = 2;
        MusicChannelWeb.playbackStateEventChannel
            .invokeMethod('', _playbackState.toMap());
        _playNow = true;
      }
    });

    _audio.onPlay.listen((event) {
      html.window.console.info('onPlayStream');
      _playbackState.state = 3;
      MusicChannelWeb.playbackStateEventChannel
          .invokeMethod('', _playbackState.toMap());
    });

    _audio.onPause.listen((event) {
      html.window.console.info('onPauseStream');
      _playbackState.state = 2;
      MusicChannelWeb.playbackStateEventChannel
          .invokeMethod('', _playbackState.toMap());
    });

    _audio.onAbort.listen((event) {
      html.window.console.warn('不是因为出错而导致的媒体数据下载中止。');
      html.window.console.warn(event);
    });
    _audio.onError.listen((event) {
      html.window.console.warn('媒体下载过程中错误。例如突然无网络了。或者文件地址不对。');
      html.window.console.warn(event);
    });
    _audio.onStalled.listen((event) {
      html.window.console.warn('媒体数据意外地不再可用。');
      html.window.console.warn(event);
    });

    _playbackState.state = 0;
    // Media Session API
    if (html.MediaStream.supported) {
      html.window.console.info('Support MediaStream And Add ActionHandler');
      html.window.navigator.mediaSession
          ?.setActionHandler('previoustrack', () => onSkipToPrevious(true));
      html.window.navigator.mediaSession
          ?.setActionHandler('nexttrack', () => onSkipToNext(false));
    }
  }

  void onPlayFromMediaId(String mediaId) {
    MusicData.get().playFromMusicId(mediaId);
    initPlay();
  }

  void onPlay() {
    html.window.console.info('onPlay');
    _audio.play().then((value) {
      _playbackState.state = 3;
      MusicChannelWeb.playbackStateEventChannel
          .invokeMethod('', _playbackState.toMap());
    }).catchError((error) {
      html.window.console.error(error);
      _playbackState.state = 3;
      MusicChannelWeb.playbackStateEventChannel
          .invokeMethod('', _playbackState.toMap());
    });
  }

  void onPause() {
    html.window.console.info('onPause');
    _audio.pause();
    _playbackState.state = 2;
    MusicChannelWeb.playbackStateEventChannel
        .invokeMethod('', _playbackState.toMap());
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
    html.window.console.info('onSkipToPrevious');
    _playbackState.state = 9;
    MusicChannelWeb.playbackStateEventChannel
        .invokeMethod('', _playbackState.toMap());
    MusicData.get().previous(userTrigger);
    initPlay();
  }

  void onSkipToNext(bool userTrigger) {
    html.window.console.info('onSkipToNext');
    _playbackState.state = 10;
    MusicChannelWeb.playbackStateEventChannel
        .invokeMethod('', _playbackState.toMap());
    MusicData.get().next(userTrigger);
    initPlay();
  }

  void initPlay() {
    html.window.console.info('initPlay');
    Music? nowPlayMusic = MusicData.get().nowPlayMusic;
    if (nowPlayMusic == null) {
      html.window.console.info('nowPlayMusic == null');
      return;
    }
    if (nowPlayMusic.musicUri == null) {
      html.window.console.info('nowPlayMusic.musicUri == null');
      return;
    }

    _audio.src = nowPlayMusic.musicUri!;
    _playbackState.state = 8;
    MusicChannelWeb.playbackStateEventChannel
        .invokeMethod('', _playbackState.toMap());
    _metaData.mediaId = nowPlayMusic.musicId ?? '';
    _metaData.title = nowPlayMusic.name ?? '';
    _metaData.subTitle = nowPlayMusic.singer ?? '';
    _metaData.coverUri = nowPlayMusic.coverUri ?? '';
    _metaData.musicUri = nowPlayMusic.musicUri ?? '';
    _metaData.lyricUri = nowPlayMusic.lyricUri ?? '';
    MusicChannelWeb.metadataEventChannel.invokeMethod('', _metaData.toMap());
    // Media Session API
    if (html.MediaStream.supported) {
      html.window.console.info('Support MediaStream');
      html.MediaMetadata metadata = html.MediaMetadata();
      metadata.title = _metaData.title;
      metadata.artist = _metaData.subTitle;
      html.window.navigator.mediaSession?.metadata = metadata;
    }
    _audio.load();
    _audio.pause();
  }
}
