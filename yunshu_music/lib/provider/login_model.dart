import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginModel extends ChangeNotifier {
  static const String _baseUrlKey = "BASE_URL";
  static const String _enableAuthorizationKey = "ENABLE_AUTHORIZATION";
  static const String _authorizationSignParamNameKey =
      "AUTHORIZATION_SIGN_PARAM_NAME";
  static const String _authorizationSignKey = "AUTHORIZATION_SIGN";
  static const String _authorizationTimeParamNameKey =
      "AUTHORIZATION_TIME_PARAM_NAME";

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

  String getSignParamName({String defaultValue = 'sign'}) {
    return sharedPreferences.getString(_authorizationSignParamNameKey) ??
        defaultValue;
  }

  Future<bool> setSignParamName(String signParamName) async {
    return await sharedPreferences.setString(
      _authorizationSignParamNameKey,
      signParamName,
    );
  }

  String? getSignKey() {
    return sharedPreferences.getString(_authorizationSignKey);
  }

  Future<bool> setSignKey(String signKey) async {
    return await sharedPreferences.setString(_authorizationSignKey, signKey);
  }

  bool getEnableAuthorization({bool defaultValue = false}) {
    return sharedPreferences.getBool(_enableAuthorizationKey) ?? defaultValue;
  }

  Future<bool> setEnableAuthorization(bool value) async {
    return await sharedPreferences.setBool(_enableAuthorizationKey, value);
  }

  String getAuthorizationTimeParamName({String defaultValue = 't'}) {
    return sharedPreferences.getString(_authorizationTimeParamNameKey) ??
        defaultValue;
  }

  Future<bool> setAuthorizationTimeParamName(String paramName) async {
    return await sharedPreferences.setString(
      _authorizationTimeParamNameKey,
      paramName,
    );
  }

  Map<String, dynamic> getAuthorizationData() {
    return {
      "ENABLE": getEnableAuthorization(),
      "SIGN_PARAM": getSignParamName(),
      "SIGN": getSignKey(),
      "TIME_PARAM": getAuthorizationTimeParamName(),
    };
  }
}
