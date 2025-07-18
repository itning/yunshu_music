import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:motion_toast/motion_toast.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yunshu_music/net/model/music_entity.dart';
import 'package:yunshu_music/page/music_list/component/music_list_item.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/provider/music_list_status_model.dart';
import 'package:yunshu_music/provider/setting_model.dart';
import 'package:yunshu_music/util/common_utils.dart';

class MusicList extends StatefulWidget {
  const MusicList({super.key});

  @override
  State<MusicList> createState() => _MusicListState();
}

class _MusicListState extends State<MusicList> {
  late ScrollController _scrollController;
  Timer? _debounce;

  /// SnackBar消息
  void message(String? message) {
    if (null == message) {
      return;
    }
    if (!mounted) {
      MotionToast.error(
        title: const Text("错误"),
        description: Text(message),
      ).show(context);
      return;
    }
    final snackBar = SnackBar(content: Text(message));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      MusicListStatusModel.get().visible = false;
      if (_debounce?.isActive ?? false) {
        _debounce!.cancel();
      }
      _debounce = Timer(const Duration(milliseconds: 500), () {
        MusicListStatusModel.get().visible = true;
      });
    });
    Provider.of<MusicDataModel>(context, listen: false)
        .refreshMusicList(needInit: true)
        .then(message)
        .onError((error, stackTrace) {
          message(error.toString());
          LogHelper.get().error('刷新歌曲列表失败', error, stackTrace);
        });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context
          .read<MusicDataModel>()
          .refreshMusicList()
          .then(message)
          .onError((error, stackTrace) {
            message(error.toString());
            LogHelper.get().error(error, stackTrace);
          }),
      child: Stack(
        children: [
          Selector<MusicDataModel, List<MusicData>>(
            selector: (_, model) => model.musicList,
            builder: (BuildContext context, musicList, Widget? child) {
              if (musicList.isEmpty) {
                return const _InnerShimmer();
              }
              return ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                  },
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemExtent: 55.0,
                    itemCount: musicList.length,
                    itemBuilder: (BuildContext context, int index) {
                      MusicData music = musicList[index];
                      return _InnerListItem(
                        index: index,
                        name: music.name ?? '',
                        singer: music.singer ?? '',
                        musicId: music.musicId ?? '',
                        lyricId: music.lyricId ?? '',
                        musicUri: music.musicUri ?? '',
                        musicDownloadUri: music.musicDownloadUri ?? '',
                      );
                    },
                  ),
                ),
              );
            },
          ),
          Positioned(
            right: 16.0,
            bottom: 16.0,
            child: Selector<MusicListStatusModel, bool>(
              selector: (_, model) => model.visible,
              builder: (BuildContext context, visible, Widget? child) =>
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: visible ? 1.0 : 0.0,
                    child: FloatingActionButton.small(
                      tooltip: '定位歌曲位置',
                      onPressed: () {
                        if (visible) {
                          _scrollController.animateTo(
                            MusicDataModel.get().nowMusicIndex * 55.0,
                            duration: const Duration(seconds: 1),
                            curve: Curves.easeOut,
                          );
                        }
                      },
                      child: const Icon(Icons.gps_fixed),
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InnerListItem extends StatelessWidget {
  final int index;
  final String name;
  final String singer;
  final String musicId;
  final String lyricId;
  final String musicUri;
  final String musicDownloadUri;

  const _InnerListItem({
    required this.index,
    required this.name,
    required this.singer,
    required this.musicId,
    required this.lyricId,
    required this.musicUri,
    required this.musicDownloadUri,
  });

  Future<bool?> showDeleteConfirmDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("提示"),
          content: const Text("您确定要删除吗?"),
          actions: <Widget>[
            TextButton(
              child: const Text("取消"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("删除"),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MusicListItem(
      index: index,
      title: name,
      subTitle: singer,
      rightButtonIcon: Icons.more_vert,
      onTap: () {
        if (context.read<SettingModel>().router2PlayPageWhenClickPlayListItem) {
          context.push('/musicPlay');
        }
        Provider.of<MusicDataModel>(
          context,
          listen: false,
        ).setNowPlayMusicUseMusicId(musicId);
      },
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: "$name-$singer")).then(
          (_) => {
            if (context.mounted)
              {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '复制成功',
                      style: TextStyle(fontFamily: 'LXGWWenKaiMono'),
                    ),
                    duration: Duration(seconds: 1),
                  ),
                ),
              },
          },
        );
      },
      rightButtonTap: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          isScrollControlled: true, // set this to true
          builder: (_) {
            return DraggableScrollableSheet(
              maxChildSize: 0.5,
              expand: false,
              builder: (_, controller) {
                return ListView(
                  controller: controller,
                  children: [
                    Container(
                      alignment: AlignmentDirectional.center,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: const Text('更多操作'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.music_note),
                      title: SelectableText(name),
                    ),
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: SelectableText(singer),
                    ),
                    ListTile(
                      leading: const Icon(Icons.download),
                      title: const Text('下载歌曲到本地'),
                      onTap: () async {
                        Uri url = Uri.parse(musicDownloadUri);
                        bool can = await canLaunchUrl(url);
                        if (can) {
                          await launchUrl(url);
                        } else {
                          if (context.mounted) {
                            MotionToast.error(
                              description: Text("下载失败"),
                            ).show(context);
                          }
                        }
                      },
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

/// 加载时占位图
class _InnerShimmer extends StatelessWidget {
  const _InnerShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Expanded(
            child: Shimmer.fromColors(
              baseColor:
                  Theme.of(context).dialogTheme.backgroundColor ?? Colors.black,
              highlightColor: Theme.of(context).highlightColor,
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (_, _) => Container(
                  margin: const EdgeInsets.only(bottom: 8.0, top: 8.0),
                  child: Flex(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    direction: Axis.horizontal,
                    children: [
                      Expanded(
                        child: Container(
                          width: 16.0,
                          height: 45.0,
                          color: Colors.white,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                      ),
                      Expanded(
                        flex: 8,
                        child: Container(
                          width: double.infinity,
                          height: 45.0,
                          color: Colors.white,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                      ),
                      Expanded(
                        child: Container(
                          width: 16.0,
                          height: 45.0,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                itemCount: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
