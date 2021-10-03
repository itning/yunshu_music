import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题
class ThemeModel extends ChangeNotifier {
  static const String _themeModeKey = "THEME_MODE";

  static ThemeModel? _instance;

  static ThemeModel get() {
    _instance ??= ThemeModel();
    return _instance!;
  }

  late ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  Future<void> init() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    String? themeMode = sharedPreferences.getString(_themeModeKey);
    _themeMode = _fromString(themeMode);
  }

  ThemeMode _fromString(String? theme) {
    if (null == theme) {
      return ThemeMode.light;
    }
    switch (theme) {
      case 'ThemeMode.system':
        return ThemeMode.system;
      case 'ThemeMode.dark':
        return ThemeMode.dark;
      case 'ThemeMode.light':
        return ThemeMode.light;
      default:
        return ThemeMode.light;
    }
  }

  Future<void> setDarkTheme(bool darkMode) async {
    await setTheme(darkMode ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> setFollowSystemTheme(bool followSystem) async {
    await setTheme(followSystem ? ThemeMode.system : ThemeMode.light);
  }

  Future<void> setTheme(ThemeMode themeMode) async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.setString(_themeModeKey, themeMode.toString());
    _themeMode = themeMode;
    notifyListeners();
  }
}
