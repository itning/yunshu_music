import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yunshu_music/method_channel/music_channel.dart';

class VolumeDataModel extends ChangeNotifier {
  static const String _volumeKey = "MUSIC_VOLUME";

  static VolumeDataModel? _instance;

  static VolumeDataModel get() {
    _instance ??= VolumeDataModel();
    return _instance!;
  }

  late SharedPreferences sharedPreferences;

  double _volume = 0.0;

  double get volume => _volume;

  VolumeDataModel() {
    if (!kIsWeb && Platform.isAndroid) {
      return;
    }
    MusicChannel.get().volumeEvent.listen((event) {
      _volume = event;
      notifyListeners();
    });
  }

  Future<void> init(SharedPreferences sharedPreferences) async {
    if (!kIsWeb && Platform.isAndroid) {
      return;
    }
    this.sharedPreferences = sharedPreferences;
    _volume = sharedPreferences.getDouble(_volumeKey) ?? 1.0;
    await MusicChannel.get().setVolume(_volume);
  }

  Future<void> setVolume(double volume) async {
    await MusicChannel.get().setVolume(_volume);
    await sharedPreferences.setDouble(_volumeKey, volume);
  }
}
