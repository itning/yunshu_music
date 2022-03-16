import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/provider/music_data_model.dart';

/// 列表项
class MusicListItem extends StatelessWidget {
  final int index;
  final String? title;
  final String? subTitle;
  final IconData? rightButtonIcon;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;
  final VoidCallback? rightButtonTap;

  const MusicListItem(
      {Key? key,
      required this.index,
      this.title,
      this.subTitle,
      this.rightButtonIcon,
      this.onTap,
      this.onLongPress,
      this.rightButtonTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: onLongPress,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8.0, top: 8.0),
        child: Flex(
          direction: Axis.horizontal,
          children: [
            Expanded(
              flex: 2,
              child: _MusicListItemIndex(index: index),
            ),
            Expanded(
              flex: 11,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$title',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16.0),
                  ),
                  Text(
                    '$subTitle',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.0, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: IconButton(
                onPressed: rightButtonTap,
                icon: Icon(rightButtonIcon, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MusicListItemIndex extends StatelessWidget {
  final int index;

  const _MusicListItemIndex({Key? key, required this.index}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Selector<MusicDataModel, int>(
      builder: (BuildContext context, i, Widget? child) {
        if (i != index) {
          return Text(
            '${index + 1}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          );
        } else {
          return const Icon(Icons.equalizer, color: Colors.black);
        }
      },
      selector: (_, model) => model.nowMusicIndex,
    );
  }
}
