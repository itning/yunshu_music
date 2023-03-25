import 'package:flutter/material.dart';
import 'package:yunshu_music/hotkey/intent.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/provider/play_status_model.dart';
import 'package:yunshu_music/util/common_utils.dart';

class PlayPauseAction extends Action<PlayPauseIntent> {
  PlayPauseAction();

  @override
  Object? invoke(covariant PlayPauseIntent intent) {
    LogHelper.get().debug('PlayPauseAction trigger');
    PlayStatusModel status = PlayStatusModel.get();
    status.setPlay(!status.isPlayNow);
    return null;
  }
}

class PreviousAction extends Action<PreviousIntent> {
  PreviousAction();

  @override
  Object? invoke(covariant PreviousIntent intent) {
    LogHelper.get().debug('PreviousAction trigger');
    MusicDataModel.get().toPrevious();
    return null;
  }
}

class NextAction extends Action<NextIntent> {
  NextAction();

  @override
  Object? invoke(covariant NextIntent intent) {
    LogHelper.get().debug('NextAction trigger');
    MusicDataModel.get().toNext();
    return null;
  }
}

class SeekBackAction extends Action<SeekBackIntent> {
  SeekBackAction();

  @override
  Object? invoke(covariant SeekBackIntent intent) {
    LogHelper.get().debug('SeekBackAction trigger');
    PlayStatusModel status = PlayStatusModel.get();
    // default decrease one seconds.
    status.seek(status.position - const Duration(seconds: 1));
    return null;
  }
}

class SeekForwardAction extends Action<SeekForwardIntent> {
  SeekForwardAction();

  @override
  Object? invoke(covariant SeekForwardIntent intent) {
    LogHelper.get().debug('SeekForwardAction trigger');
    PlayStatusModel status = PlayStatusModel.get();
    // default add one seconds.
    status.seek(status.position + const Duration(seconds: 1));
    return null;
  }
}
