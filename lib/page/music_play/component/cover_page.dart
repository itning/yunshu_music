import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/component/rotate_cover_image_widget.dart';
import 'package:yunshu_music/provider/music_data_model.dart';

/// 封面页
class CoverPage extends StatefulWidget {
  const CoverPage({Key? key}) : super(key: key);

  @override
  State<CoverPage> createState() => _CoverPageState();
}

class _CoverPageState extends State<CoverPage>
    with AutomaticKeepAliveClientMixin<CoverPage> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    print('>>>CoverPage build');
    return Center(
      child: Selector<MusicDataModel, String>(
        shouldRebuild: (a, b) {
          // TODO ITNING:都没封面的时候 需要重新构建
          print('>>>CoverPage shouldRebuild');
          return a != b;
        },
        selector: (_, model) => model.coverBase64,
        builder: (BuildContext context, value, Widget? child) {
          return RotateCoverImageWidget(
            width: 225,
            height: 225,
            duration: const Duration(seconds: 20),
            name: value,
          );
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
