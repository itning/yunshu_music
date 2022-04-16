import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginModel extends ChangeNotifier {
  static const String _baseUrlKey = "BASE_URL";

  static LoginModel? _instance;

  static LoginModel get() {
    _instance ??= LoginModel();
    return _instance!;
  }

  late SharedPreferences sharedPreferences;

  Future<void> init(SharedPreferences sharedPreferences) async {
    this.sharedPreferences = sharedPreferences;
  }

  bool isLogin() {
    return sharedPreferences.getString(_baseUrlKey) != null;
  }

  Future<bool> setBaseUrl(String url) async {
    return await sharedPreferences.setString(_baseUrlKey, url);
  }

  String? getBaseUrl() {
    return sharedPreferences.getString(_baseUrlKey);
  }
}
