import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/component/rotate_cover_image_widget.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/util/common_utils.dart';

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
    return Center(
      child: Selector<MusicDataModel, Uint8List?>(
        selector: (_, model) => model.coverBase64,
        builder: (_, value, __) {
          bool largeMode = isLargeMode(context);
          if (value == null) {
            return RotateCoverImageWidget(
              width: largeMode ? 350 : 225,
              height: largeMode ? 350 : 225,
              duration: const Duration(seconds: 20),
              image: Image.asset('asserts/images/default_cover.jpg').image,
            );
          } else {
            return RotateCoverImageWidget(
              width: largeMode ? 350 : 225,
              height: largeMode ? 350 : 225,
              duration: const Duration(seconds: 20),
              image: Image.memory(value).image,
            );
          }
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
