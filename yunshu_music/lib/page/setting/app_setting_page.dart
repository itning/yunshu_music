import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_update_dialog/flutter_update_dialog.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yunshu_music/provider/cache_model.dart';
import 'package:yunshu_music/provider/theme_model.dart';

/// 应用设置页面
class AppSettingPage extends StatelessWidget {
  const AppSettingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16.0, top: 16.0),
            child: Text(
              '主题设置',
              style: TextStyle(fontSize: 12.0),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  '夜间模式',
                  style: TextStyle(fontSize: 17.0),
                ),
              ),
              Selector<ThemeModel, bool>(
                selector: (_, theme) {
                  return theme.themeMode == ThemeMode.dark;
                },
                builder: (BuildContext context, darkMode, _) {
                  return Switch(
                      value: darkMode,
                      onChanged: (value) =>
                          context.read<ThemeModel>().setDarkTheme(value));
                },
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  '跟随系统',
                  style: TextStyle(fontSize: 17.0),
                ),
              ),
              Selector<ThemeModel, bool>(
                selector: (_, theme) {
                  return theme.themeMode == ThemeMode.system;
                },
                builder: (BuildContext context, darkMode, _) {
                  return Switch(
                      value: darkMode,
                      onChanged: (value) => context
                          .read<ThemeModel>()
                          .setFollowSystemTheme(value));
                },
              ),
            ],
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.only(left: 16.0, top: 16.0),
            child: Text(
              '缓存设置',
              style: TextStyle(fontSize: 12.0),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  '开启歌曲缓存',
                  style: TextStyle(fontSize: 17.0),
                ),
              ),
              Selector<CacheModel, bool>(
                selector: (_, cache) {
                  return cache.enableMusicCache;
                },
                builder: (BuildContext context, enable, _) {
                  return Switch(
                      value: enable,
                      onChanged: (value) => context
                          .read<CacheModel>()
                          .setEnableMusicCache(value));
                },
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  '开启封面缓存',
                  style: TextStyle(fontSize: 17.0),
                ),
              ),
              Selector<CacheModel, bool>(
                selector: (_, cache) {
                  return cache.enableCoverCache;
                },
                builder: (BuildContext context, enable, _) {
                  return Switch(
                      value: enable,
                      onChanged: (value) => context
                          .read<CacheModel>()
                          .setEnableCoverCache(value));
                },
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  '开启歌词缓存',
                  style: TextStyle(fontSize: 17.0),
                ),
              ),
              Selector<CacheModel, bool>(
                selector: (_, cache) {
                  return cache.enableLyricCache;
                },
                builder: (BuildContext context, enable, _) {
                  return Switch(
                      value: enable,
                      onChanged: (value) => context
                          .read<CacheModel>()
                          .setEnableLyricCache(value));
                },
              ),
            ],
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.only(left: 16.0, top: 16.0),
            child: Text(
              '关于',
              style: TextStyle(fontSize: 12.0),
            ),
          ),
          InkWell(
            onTap: () {
              if (!kIsWeb) {
                UpdateDialog _ = UpdateDialog.showUpdate(
                  context,
                  title: "检测到新版本",
                  updateContent: "点击升级按钮下载新版本",
                  updateButtonText: '升级',
                  onUpdate: () async {
                    bool can = await canLaunch(
                        'https://github.com/itning/yunshu_music');
                    if (can) {
                      await launch('https://github.com/itning/yunshu_music');
                    } else {
                      Fluttertoast.showToast(msg: "无法升级");
                    }
                  },
                );
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    '版本',
                    style: TextStyle(fontSize: 17.0),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FutureBuilder(
                      future: PackageInfo.fromPlatform(),
                      builder: (BuildContext context,
                          AsyncSnapshot<PackageInfo> snapshot) {
                        // 请求已结束
                        if (snapshot.connectionState == ConnectionState.done) {
                          return Text(
                            snapshot.hasError
                                ? '未知'
                                : '${snapshot.data?.version}(${snapshot.data?.buildNumber})',
                            style: const TextStyle(fontSize: 17.0),
                          );
                        } else {
                          // 请求未结束，显示loading
                          return const Text(
                            '加载中',
                            style: TextStyle(fontSize: 17.0),
                          );
                        }
                      }),
                )
              ],
            ),
          ),
          InkWell(
            onTap: () async {
              bool can =
                  await canLaunch('https://github.com/itning/yunshu_music');
              if (can) {
                await launch('https://github.com/itning/yunshu_music');
              } else {
                Fluttertoast.showToast(msg: "无法打开");
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'GitHub',
                    style: TextStyle(fontSize: 17.0),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Icon(
                    Icons.open_in_new,
                    size: 17.0,
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
