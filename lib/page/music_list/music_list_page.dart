import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:move_to_background/move_to_background.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/page/music_list/component/music_mini_play_controller_widget.dart';
import 'package:yunshu_music/page/music_play/music_play_page.dart';
import 'package:yunshu_music/provider/music_data_model.dart';

/// 音乐列表
class MusicListPage extends StatefulWidget {
  const MusicListPage({Key? key}) : super(key: key);

  @override
  _MusicListPageState createState() => _MusicListPageState();
}

class _MusicListPageState extends State<MusicListPage> {
  /// SnackBar消息
  void message(String? message) {
    if (null == message) {
      return;
    }
    if (!mounted) {
      print("message: $message");
      return;
    }
    final snackBar = SnackBar(content: Text(message));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Route _createRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const MusicPlayPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: animation.drive(
            Tween(begin: const Offset(0.0, 1.0), end: Offset.zero).chain(
              CurveTween(curve: Curves.linear),
            ),
          ),
          child: child,
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    Provider.of<MusicDataModel>(context, listen: false)
        .refreshMusicList(needInit: true)
        .then(message)
        .onError((error, stackTrace) {
      message(error.toString());
      print(error);
      print(stackTrace);
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        MoveToBackground.moveTaskToBack();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('云舒音乐')),
        body: RefreshIndicator(
          onRefresh: () => context
              .read<MusicDataModel>()
              .refreshMusicList()
              .then(message)
              .onError((error, stackTrace) {
            message(error.toString());
            print(error);
            print(stackTrace);
          }),
          child: Consumer<MusicDataModel>(
              builder: (BuildContext context, value, Widget? child) {
            // TODO ITNING:性能优化
            return Scrollbar(
              child: ListView.builder(
                  itemCount: value.musicList.length,
                  itemBuilder: (BuildContext context, int index) {
                    return _ListItem(
                      serialNumber: index + 1,
                      title: value.musicList[index].name,
                      subTitle: value.musicList[index].singer,
                      rightButtonIcon: Icons.more_vert,
                      onTap: () {
                        Navigator.push(context, _createRoute());
                        Provider.of<MusicDataModel>(context, listen: false)
                            .setNowPlayMusic(index);
                      },
                      onLongPress: () {
                        Clipboard.setData(ClipboardData(
                                text:
                                    "${value.musicList[index].name}-${value.musicList[index].singer}"))
                            .then((_) => ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(
                                  content: Text('复制成功'),
                                  duration: Duration(seconds: 1),
                                )));
                      },
                    );
                  }),
            );
          }),
        ),
        bottomNavigationBar: const MusicMiniPlayControllerWidget(),
      ),
    );
  }
}

/// 列表项
class _ListItem extends StatelessWidget {
  final int? serialNumber;
  final String? title;
  final String? subTitle;
  final IconData? rightButtonIcon;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;

  const _ListItem(
      {Key? key,
      this.serialNumber,
      this.title,
      this.subTitle,
      this.rightButtonIcon,
      this.onTap,
      this.onLongPress})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: onLongPress,
      onTap: onTap,
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
