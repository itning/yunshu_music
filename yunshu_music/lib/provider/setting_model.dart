import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingModel extends ChangeNotifier {
  static const String _router2PlayPageWhenClickPlayListItemKey =
      "ROUTER_2_PLAY_PAGE_WHEN_CLICK_PLAY_LIST_ITEM";

  static const String _playPageAutoChangeLargeModeKey =
      "PLAY_PAGE_AUTO_CHANGE_LARGE_MODE";

  static SettingModel? _instance;

  static SettingModel get() {
    _instance ??= SettingModel();
    return _instance!;
  }

  late SharedPreferences sharedPreferences;

  late bool _router2PlayPageWhenClickPlayListItem;

  late bool _playPageAutoChangeLargeMode;

  bool get router2PlayPageWhenClickPlayListItem =>
      _router2PlayPageWhenClickPlayListItem;

  bool get playPageAutoChangeLargeMode => _playPageAutoChangeLargeMode;

  SettingModel() {}

  Future<void> init(SharedPreferences sharedPreferences) async {
    this.sharedPreferences = sharedPreferences;
    _router2PlayPageWhenClickPlayListItem =
        sharedPreferences.getBool(_router2PlayPageWhenClickPlayListItemKey) ??
            true;
    _playPageAutoChangeLargeMode =
        sharedPreferences.getBool(_playPageAutoChangeLargeModeKey) ?? true;
  }

  Future<void> setRouter2PlayPageWhenClickPlayListItem(bool enabled) async {
    await sharedPreferences.setBool(
        _router2PlayPageWhenClickPlayListItemKey, enabled);
    _router2PlayPageWhenClickPlayListItem = enabled;
    notifyListeners();
  }

  Future<void> setPlayPageAutoChangeLargeMode(bool enabled) async {
    await sharedPreferences.setBool(_playPageAutoChangeLargeModeKey, enabled);
    _playPageAutoChangeLargeMode = enabled;
    notifyListeners();
  }
}
