import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.modulate),
          image: Image.memory(
            base64Decode(context
                .select<MusicDataModel, String>((value) => value.coverBase64)),
            excludeFromSemantics: true,
            gaplessPlayback: true,
          ).image,
          fit: BoxFit.cover,
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 100.0, sigmaY: 100.0),
        child: Scaffold(
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
        ),
      ),
    );
  }
}

// class MusicPlayPage extends StatelessWidget {
//   const MusicPlayPage({Key? key}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         const BackgroundPicture(),
//         BackdropFilter(
//           filter: ImageFilter.blur(sigmaX: 100.0, sigmaY: 100.0),
//           child: Scaffold(
//             backgroundColor: Colors.transparent,
//             appBar: AppBar(
//               centerTitle: true,
//               title: const TitleMusicInfo(),
//               elevation: 0,
//               backgroundColor: Colors.transparent,
//             ),
//             body: PageView.builder(
//               itemCount: 2,
//               itemBuilder: (BuildContext context, int index) {
//                 if (index == 0) {
//                   return const CoverPage();
//                 } else {
//                   return const LyricPage();
//                 }
//               },
//             ),
//             bottomNavigationBar: const PlayerPageBottomNavigationBar(),
//           ),
//         )
//       ],
//     );
//   }
// }
//
// class BackgroundPicture extends StatelessWidget {
//   const BackgroundPicture({Key? key}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Image.memory(base64Decode(
//         context.select<MusicDataModel, String>((value) => value.coverBase64)));
//   }
// }
