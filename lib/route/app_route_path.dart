import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:yunshu_music/page/music_list/music_index_page.dart';
import 'package:yunshu_music/page/music_play/music_play_page.dart';
import 'package:yunshu_music/page/setting/app_setting_page.dart';

class AppRoutePath {
  static AppRoutePath createPage(String? path) {
    if (null == path) {
      return AppRoutePath(widget: const MusicIndexPage(), path: '/');
    }
    switch (path) {
      case "/":
        return AppRoutePath(widget: const MusicIndexPage(), path: path);
      case "/musicPlay":
        return AppRoutePath(widget: const MusicPlayPage(), path: path);
      case "/setting":
        return AppRoutePath(widget: const AppSettingPage(), path: path);
      default:
        return AppRoutePath(widget: const MusicIndexPage(), path: '/');
    }
  }

  final Widget widget;

  final String path;

  AppRoutePath({required this.widget, required this.path});

  /// 生成一个Page
  MaterialPage generatePage() {
    return MaterialPage(key: ValueKey(path), name: path, child: widget);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppRoutePath &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;
}
