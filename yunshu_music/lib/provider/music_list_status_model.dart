import 'package:flutter/material.dart';

/// 音乐列表状态
class MusicListStatusModel extends ChangeNotifier {
  static MusicListStatusModel? _instance;

  static MusicListStatusModel get() {
    _instance ??= MusicListStatusModel();
    return _instance!;
  }

  bool _visible = true;

  bool get visible => _visible;

  set visible(bool status) {
    _visible = status;
    notifyListeners();
  }
}
