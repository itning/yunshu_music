import 'package:flutter/material.dart';
import 'package:yunshu_music/page/music_play/component/player_page_controller.dart';
import 'package:yunshu_music/page/music_play/component/player_page_progress.dart';

class PlayerPageBottomNavigationBar extends StatelessWidget {
  const PlayerPageBottomNavigationBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112.0,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [PlayerPageProgress(), PlayerPageController()],
      ),
    );
  }
}
