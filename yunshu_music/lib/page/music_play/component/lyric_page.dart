import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/component/lyric/lyric.dart';
import 'package:yunshu_music/component/lyric/lyric_controller.dart';
import 'package:yunshu_music/component/lyric/lyric_view.dart';
import 'package:yunshu_music/component/volume_slider.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/provider/play_status_model.dart';

/// 歌词页
class LyricPage extends StatefulWidget {
  const LyricPage({super.key});

  @override
  State<LyricPage> createState() => _LyricPageState();
}

class _LyricPageState extends State<LyricPage>
    with AutomaticKeepAliveClientMixin<LyricPage> {
  final LyricController _controller = LyricController();

  PlayStatusModel? _playStatus;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final PlayStatusModel playStatus = context.read<PlayStatusModel>();
    if (!identical(_playStatus, playStatus)) {
      _playStatus?.removeListener(_onPositionChanged);
      _playStatus = playStatus;
      playStatus.addListener(_onPositionChanged);
      _controller.updatePosition(playStatus.position);
    }
  }

  void _onPositionChanged() {
    _controller.updatePosition(_playStatus?.position ?? Duration.zero);
  }

  @override
  void dispose() {
    _playStatus?.removeListener(_onPositionChanged);
    _controller.dispose();
    if (!kIsWeb && Platform.isAndroid) {
      FlutterWindowManagerPlus.clearFlags(
        FlutterWindowManagerPlus.FLAG_KEEP_SCREEN_ON,
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: <Widget>[
        if (kIsWeb || !Platform.isAndroid) const VolumeSlider(),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Center(
                child: Selector<MusicDataModel, List<Lyric>?>(
                  selector: (_, data) => data.lyricList,
                  builder: (_, value, _) {
                    if (null == value || value.isEmpty) {
                      return const Text(
                        '该歌曲暂无歌词',
                        style: TextStyle(color: Colors.white),
                      );
                    }
                    return RepaintBoundary(
                      child: LyricView(
                        key: ValueKey(value),
                        size: const Size(double.infinity, double.infinity),
                        lyrics: value,
                        controller: _controller,
                      ),
                    );
                  },
                ),
              ),
              ListenableBuilder(
                listenable: _controller,
                builder: (BuildContext context, _) {
                  return Offstage(
                    offstage: !_controller.isDragging,
                    child: GestureDetector(
                      onTap: () {
                        _controller.completeDrag();
                        context.read<PlayStatusModel>().seek(
                          _controller.draggingProgress,
                        );
                      },
                      child: Row(
                        children: const [
                          Icon(Icons.play_arrow, color: Colors.white),
                          Expanded(child: Divider(color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
