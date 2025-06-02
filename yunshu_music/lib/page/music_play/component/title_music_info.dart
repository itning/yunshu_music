import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/net/model/music_entity.dart';
import 'package:yunshu_music/provider/music_data_model.dart';

class TitleMusicInfo extends StatelessWidget {
  const TitleMusicInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<MusicDataModel, MusicData?>(
      selector: (_, model) => model.getNowPlayMusic(),
      builder: (BuildContext context, value, Widget? child) {
        if (value == null) {
          return const Text('云舒音乐');
        }
        return Column(
          children: [
            Text(
              value.name ?? '',
              style: const TextStyle(fontSize: 18.0),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              value.singer ?? '',
              style: const TextStyle(fontSize: 10.0),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}
