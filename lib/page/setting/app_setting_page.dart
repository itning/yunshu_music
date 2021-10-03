import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                      onChanged: (value) => context
                          .read<ThemeModel>()
                          .setDarkTheme(value));
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
        ],
      ),
    );
  }
}
