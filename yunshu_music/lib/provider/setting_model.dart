import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingModel extends ChangeNotifier {
  static const String _router2PlayPageWhenClickPlayListItemKey =
      "ROUTER_2_PLAY_PAGE_WHEN_CLICK_PLAY_LIST_ITEM";

  static SettingModel? _instance;

  static SettingModel get() {
    _instance ??= SettingModel();
    return _instance!;
  }

  late SharedPreferences sharedPreferences;

  late bool _router2PlayPageWhenClickPlayListItem;

  bool get router2PlayPageWhenClickPlayListItem =>
      _router2PlayPageWhenClickPlayListItem;

  SettingModel() {}

  Future<void> init(SharedPreferences sharedPreferences) async {
    this.sharedPreferences = sharedPreferences;
    _router2PlayPageWhenClickPlayListItem =
        sharedPreferences.getBool(_router2PlayPageWhenClickPlayListItemKey) ??
            true;
  }

  Future<void> setRouter2PlayPageWhenClickPlayListItem(bool enabled) async {
    await sharedPreferences.setBool(
        _router2PlayPageWhenClickPlayListItemKey, enabled);
    _router2PlayPageWhenClickPlayListItem = enabled;
    notifyListeners();
  }
}
