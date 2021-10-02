import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:yunshu_music/provider/play_status_model.dart';

class PlayerPageProgress extends StatelessWidget {
  const PlayerPageProgress({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(
          start: 16.0, end: 16.0, bottom: 12.0),
      child: Flex(
        direction: Axis.horizontal,
        children: [
          const Expanded(
            child: _ProgressStartTitle(),
          ),
          Expanded(
            flex: 8,
            child: Container(
              margin: const EdgeInsetsDirectional.only(start: 6.0, end: 6.0),
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  // 轨道高度
                  trackHeight: 2,
                  // 滑块形状，可以自定义
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 4, // 滑块大小
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    // 滑块外圈形状，可以自定义
                    overlayRadius: 10, // 滑块外圈大小
                  ),
                ),
                child: const _ProgressSlider(),
              ),
            ),
          ),
          const Expanded(
            child: _ProgressEndTitle(),
          ),
        ],
      ),
    );
  }
}

String _printDuration(Duration duration) {
  int seconds = duration.inSeconds;
  return '${(seconds / 60).floor()}'.padLeft(2, '0') +
      ':' +
      '${seconds % 60}'.padLeft(2, '0');
}

class _ProgressStartTitle extends StatelessWidget {
  const _ProgressStartTitle({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      _printDuration(
          context.select<PlayStatusModel, Duration>((value) => value.position)),
      style: const TextStyle(color: Colors.white),
    );
  }
}

class _ProgressEndTitle extends StatelessWidget {
  const _ProgressEndTitle({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      _printDuration(
          context.select<PlayStatusModel, Duration>((value) => value.duration)),
      style: const TextStyle(color: Colors.white),
    );
  }
}

class _ProgressSlider extends StatelessWidget {
  const _ProgressSlider({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Selector<PlayStatusModel, Tuple2<double, double>>(
      builder: (context, Tuple2<double, double> value, _) => Slider(
        min: 0,
        max: value.item1,
        onChanged: (double value) => context
            .read<PlayStatusModel>()
            .seek(Duration(milliseconds: value.toInt())),
        value: value.item2 > value.item1 ? value.item1 : value.item2,
      ),
      selector: (_, status) => Tuple2(
        status.duration.inMilliseconds.toDouble(),
        status.position.inMilliseconds.toDouble(),
      ),
    );
  }
}
