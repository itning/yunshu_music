import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/net/model/music_entity.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/util/common_utils.dart';

class TitleMusicInfo extends StatelessWidget {
  const TitleMusicInfo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Selector<MusicDataModel, MusicDataContent?>(
      selector: (_, model) => model.getNowPlayMusic(),
      builder: (BuildContext context, value, Widget? child) {
        if (value == null) {
          if (kIsWeb) {
            setTitle(context, '云舒音乐');
          }
          return const Text('云舒音乐');
        }
        if (kIsWeb) {
          setTitle(context, '${value.name}-${value.singer}');
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
