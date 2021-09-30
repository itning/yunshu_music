import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 音乐列表
class MusicListPage extends StatefulWidget {
  const MusicListPage({Key? key}) : super(key: key);

  @override
  _MusicListPageState createState() => _MusicListPageState();
}

class _MusicListPageState extends State<MusicListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('云舒音乐')),
      body: ListView.builder(
          itemCount: 150,
          itemBuilder: (BuildContext context, int index) {
            return _ListItem(
              serialNumber: index + 1,
              title: '音乐标题音乐标题音乐标题音乐标题音乐标题音乐标题音乐标题音乐标题音乐标题音乐标题音乐标题音乐标题',
              subTitle: '歌手歌手歌手歌手歌手歌手歌手歌手歌手歌手歌手歌手歌手歌手歌手',
              rightButtonIcon: Icons.more_vert,
            );
          }),
    );
  }
}

/// 列表项
class _ListItem extends StatelessWidget {
  final int? serialNumber;
  final String? title;
  final String? subTitle;
  final IconData? rightButtonIcon;

  const _ListItem(
      {Key? key,
      this.serialNumber,
      this.title,
      this.subTitle,
      this.rightButtonIcon})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: () {
        // TODO ITNING:长按复制？
        print('长按点击了');
      },
      onTap: () {
        // TODO ITNING:设置点击播放
        print('短按点击了');
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8.0, top: 8.0),
        child: Flex(
          direction: Axis.horizontal,
          children: [
            Expanded(
              child: Text(
                '$serialNumber',
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 8,
              child: Column(
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
                    style: const TextStyle(fontSize: 12.0),
                  ),
                ],
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () {
                  // TODO ITNING:右按钮点击
                  print('右按钮点击了');
                },
                child: Container(
                  height: 46.0,
                  alignment: AlignmentDirectional.center,
                  child: Icon(rightButtonIcon),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
