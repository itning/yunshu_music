import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingModel extends ChangeNotifier {
  static const String _router2PlayPageWhenClickPlayListItemKey =
      "ROUTER_2_PLAY_PAGE_WHEN_CLICK_PLAY_LIST_ITEM";

  static const String _playPageAutoChangeLargeModeKey =
      "PLAY_PAGE_AUTO_CHANGE_LARGE_MODE";

  static const String _useMaterial3ThemeKey = "USE_MATERIAL3_THEME";

  static const String _enableMusicCoverRotatingKey =
      "ENABLE_MUSIC_COVER_ROTATING";

  static SettingModel? _instance;

  static SettingModel get() {
    _instance ??= SettingModel();
    return _instance!;
  }

  late SharedPreferences sharedPreferences;

  late bool _router2PlayPageWhenClickPlayListItem;

  late bool _playPageAutoChangeLargeMode;

  late bool _useMaterial3Theme;

  late bool _enableMusicCoverRotating;

  bool get router2PlayPageWhenClickPlayListItem =>
      _router2PlayPageWhenClickPlayListItem;

  bool get playPageAutoChangeLargeMode => _playPageAutoChangeLargeMode;

  bool get useMaterial3Theme => _useMaterial3Theme;

  bool get enableMusicCoverRotating => _enableMusicCoverRotating;

  SettingModel();

  Future<void> init(SharedPreferences sharedPreferences) async {
    this.sharedPreferences = sharedPreferences;
    _router2PlayPageWhenClickPlayListItem =
        sharedPreferences.getBool(_router2PlayPageWhenClickPlayListItemKey) ??
        true;
    _playPageAutoChangeLargeMode =
        sharedPreferences.getBool(_playPageAutoChangeLargeModeKey) ?? true;

    _useMaterial3Theme =
        sharedPreferences.getBool(_useMaterial3ThemeKey) ?? true;

    _enableMusicCoverRotating =
        sharedPreferences.getBool(_enableMusicCoverRotatingKey) ?? true;
  }

  Future<void> setRouter2PlayPageWhenClickPlayListItem(bool enabled) async {
    await sharedPreferences.setBool(
      _router2PlayPageWhenClickPlayListItemKey,
      enabled,
    );
    _router2PlayPageWhenClickPlayListItem = enabled;
    notifyListeners();
  }

  Future<void> setPlayPageAutoChangeLargeMode(bool enabled) async {
    await sharedPreferences.setBool(_playPageAutoChangeLargeModeKey, enabled);
    _playPageAutoChangeLargeMode = enabled;
    notifyListeners();
  }

  Future<void> setUseMaterial3Theme(bool enabled) async {
    await sharedPreferences.setBool(_useMaterial3ThemeKey, enabled);
    _useMaterial3Theme = enabled;
    notifyListeners();
  }

  Future<void> setEnableMusicCoverRotating(bool enabled) async {
    await sharedPreferences.setBool(_enableMusicCoverRotatingKey, enabled);
    _enableMusicCoverRotating = enabled;
    notifyListeners();
  }
}
