import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:yunshu_music/provider/play_status_model.dart';

/// 播放页进度
class PlayerPageProgress extends StatelessWidget {
  const PlayerPageProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(
        start: 16.0,
        end: 16.0,
        bottom: 12.0,
      ),
      child: Selector<PlayStatusModel, Tuple3<Duration, Duration, Duration>>(
        builder: (context, value, _) => ProgressBar(
          timeLabelLocation: TimeLabelLocation.sides,
          progressBarColor: Colors.white,
          baseBarColor: Colors.white.withAlpha((255.0 * 0.24).round()),
          bufferedBarColor: Colors.white.withAlpha((255 * 0.24).round()),
          thumbColor: Colors.white,
          thumbGlowColor: Colors.white,
          timeLabelTextStyle: const TextStyle(color: Colors.white),
          thumbGlowRadius: 15.0,
          barHeight: 3.0,
          thumbRadius: 5.0,
          total: value.item1,
          progress: value.item2,
          buffered: value.item3,
          onSeek: (duration) => context.read<PlayStatusModel>().seek(duration),
        ),
        selector: (_, status) =>
            Tuple3(status.duration, status.position, status.bufferedPosition),
      ),
    );
  }
}
