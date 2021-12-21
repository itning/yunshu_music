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
      print('onEnd');
      _playbackState.state = 0;
      MusicChannelWeb.playbackStateEventChannel
          .invokeMethod('', _playbackState.toMap());
      onSkipToNext();
    });

    _audio.onCanPlay.listen((event) {
      print('onCanPlay');
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
      print('onPlayStream');
      _playbackState.state = 3;
      MusicChannelWeb.playbackStateEventChannel
          .invokeMethod('', _playbackState.toMap());
    });

    _audio.onPause.listen((event) {
      print('onPauseStream');
      _playbackState.state = 2;
      MusicChannelWeb.playbackStateEventChannel
          .invokeMethod('', _playbackState.toMap());
    });
    _playbackState.state = 0;
    // Media Session API
    if (html.MediaStream.supported) {
      print('Support MediaStream And Add ActionHandler');
      html.window.navigator.mediaSession
          ?.setActionHandler('previoustrack', () => onSkipToPrevious());
      html.window.navigator.mediaSession
          ?.setActionHandler('nexttrack', () => onSkipToNext());
    }
  }

  void onPlayFromMediaId(String mediaId) {
    MusicData.get().playFromMusicId(mediaId);
    initPlay();
  }

  void onPlay() {
    print('onPlay');
    _audio.play();
    _playbackState.state = 3;
    MusicChannelWeb.playbackStateEventChannel
        .invokeMethod('', _playbackState.toMap());
  }

  void onPause() {
    print('onPause');
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

  void onSkipToPrevious() {
    print('onSkipToPrevious');
    _playbackState.state = 9;
    MusicChannelWeb.playbackStateEventChannel
        .invokeMethod('', _playbackState.toMap());
    MusicData.get().previous();
    initPlay();
  }

  void onSkipToNext() {
    print('onSkipToNext');
    _playbackState.state = 10;
    MusicChannelWeb.playbackStateEventChannel
        .invokeMethod('', _playbackState.toMap());
    MusicData.get().next();
    initPlay();
  }

  void initPlay() {
    print('initPlay');
    Music? nowPlayMusic = MusicData.get().nowPlayMusic;
    if (nowPlayMusic == null) {
      return;
    }

    _audio.src = 'https://music.itning.top/file?id=${nowPlayMusic.musicId}';
    _playbackState.state = 8;
    MusicChannelWeb.playbackStateEventChannel
        .invokeMethod('', _playbackState.toMap());
    _metaData.mediaId = nowPlayMusic.musicId ?? '';
    _metaData.title = nowPlayMusic.name ?? '';
    _metaData.subTitle = nowPlayMusic.singer ?? '';
    MusicChannelWeb.metadataEventChannel.invokeMethod('', _metaData.toMap());
    // Media Session API
    if (html.MediaStream.supported) {
      print('Support MediaStream');
      html.MediaMetadata metadata = html.MediaMetadata();
      metadata.title = _metaData.title;
      metadata.artist = _metaData.subTitle;
      html.window.navigator.mediaSession?.metadata = metadata;
    }
    _audio.load();
    _audio.pause();
  }
}
