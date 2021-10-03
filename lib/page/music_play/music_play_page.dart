import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/component/image_fade.dart';
import 'package:yunshu_music/page/music_play/component/cover_page.dart';
import 'package:yunshu_music/page/music_play/component/lyric_page.dart';
import 'package:yunshu_music/page/music_play/component/player_page_bottom_navigation_bar.dart';
import 'package:yunshu_music/page/music_play/component/title_music_info.dart';
import 'package:yunshu_music/provider/music_data_model.dart';

/// 音乐播放页面
class MusicPlayPage extends StatelessWidget {
  const MusicPlayPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.modulate),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
            child: const BackgroundPicture(),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            centerTitle: true,
            title: const TitleMusicInfo(),
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          body: PageView.builder(
            itemCount: 2,
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return const CoverPage();
              } else {
                return const LyricPage();
              }
            },
          ),
          bottomNavigationBar: const PlayerPageBottomNavigationBar(),
        )
      ],
    );
  }
}

class BackgroundPicture extends StatelessWidget {
  const BackgroundPicture({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ImageFade(
      excludeFromSemantics: true,
      fit: BoxFit.cover,
      image: Image.memory(base64Decode(context
          .select<MusicDataModel, String>((value) => value.coverBase64))).image,
    );
  }
}
