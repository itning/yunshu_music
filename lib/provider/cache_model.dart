import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mime_type/mime_type.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:yunshu_music/net/http_helper.dart';
import 'package:yunshu_music/net/model/music_entity.dart';
import 'package:yunshu_music/util/common_utils.dart';

class CacheModel extends ChangeNotifier {
  static const String _enableMusicCacheKey = "ENABLE_MUSIC_CACHE";
  static const String _enableCoverCacheKey = "ENABLE_COVER_CACHE";
  static const String _enableLyricCacheKey = "ENABLE_LYRIC_CACHE";

  static CacheModel? _instance;

  static CacheModel get() {
    _instance ??= CacheModel();
    return _instance!;
  }

  late Database _database;

  bool _enableMusicCache = true;

  bool _enableCoverCache = true;

  bool _enableLyricCache = true;

  late SharedPreferences _sharedPreferences;

  bool get enableMusicCache => _enableMusicCache;

  bool get enableCoverCache => _enableCoverCache;

  bool get enableLyricCache => _enableLyricCache;

  Future<void> init(SharedPreferences sharedPreferences) async {
    _sharedPreferences = sharedPreferences;
    _enableMusicCache = sharedPreferences.getBool(_enableMusicCacheKey) ?? true;
    _enableCoverCache = sharedPreferences.getBool(_enableCoverCacheKey) ?? true;
    _enableLyricCache = sharedPreferences.getBool(_enableLyricCacheKey) ?? true;
    _database = await openDatabase('cache.db', version: 1,
        onCreate: (Database db, int version) async {
      // 所有音乐列表 缓存
      await db.execute(
          'CREATE TABLE list_cache (musicId TEXT PRIMARY KEY, lyricId TEXT, name TEXT, singer TEXT, type INTEGER)');
      // 歌词 缓存
      await db.execute(
          'CREATE TABLE lyric_cache (lyricId TEXT PRIMARY KEY, data TEXT)');
    });
  }

  Future<int> cacheMusicList(List<MusicDataContent> list) async {
    LogHelper.get().info('start cache music list');
    return await _database.transaction((txn) async {
      await txn.rawDelete('DELETE FROM list_cache');
      int change = 0;
      for (int i = 0; i < list.length; i++) {
        MusicDataContent item = list[i];
        try {
          change += await txn.insert('list_cache', {
            'musicId': item.musicId,
            'lyricId': item.lyricId,
            'name': item.name,
            'singer': item.singer,
            'type': item.type
          });
        } catch (e) {
          LogHelper.get().error("插入数据库出错", e);
          Fluttertoast.showToast(
              msg: '缓存音乐列表出错', toastLength: Toast.LENGTH_LONG);
          await txn.rawDelete('DELETE FROM list_cache');
          return 0;
        }
      }
      return change;
    });
  }

  Future<List<MusicDataContent>> getMusicList() async {
    LogHelper.get().info('get music list from cache');
    List<Map<String, Object?>> list = await _database.query('list_cache');
    if (list.isEmpty) {
      return [];
    }
    return list.map((e) => MusicDataContent().fromJson(e)).toList();
  }

  Future<int> cacheLyric(String lyricId, String? content) async {
    if (!_enableLyricCache) {
      return 0;
    }
    LogHelper.get().info('start cache lyric');
    if (content == null || content == '') {
      return 0;
    }
    return await _database.transaction((txn) async {
      await txn
          .rawDelete('DELETE FROM lyric_cache where lyricId = ?', [lyricId]);
      return await txn.rawInsert(
          'INSERT INTO lyric_cache (lyricId,data) VALUES ("$lyricId","$content");');
    });
  }

  Future<int> deleteLyric(String lyricId) async {
    LogHelper.get().info('start delete cache lyric $lyricId');
    if (lyricId == '') {
      return 0;
    }
    return await _database
        .rawDelete('delete from lyric_cache where lyricId = ?', [lyricId]);
  }

  Future<String?> getLyric(String lyricId) async {
    if (!_enableLyricCache) {
      return null;
    }
    LogHelper.get().info('get lyric from cache $lyricId');
    List<Map<String, Object?>> list = await _database
        .rawQuery('select * from lyric_cache where lyricId = "$lyricId";');
    if (list.isEmpty) {
      return null;
    }
    return list[0]['data']?.toString();
  }

  Future<File?> cacheCover(
      String musicId, List<int>? by, String? mimeType) async {
    if (null == by) {
      return null;
    }
    String ext =
    mimeType == null ? 'png' : extensionFromMime(mimeType) ?? 'png';
    if (ext == 'jpe') {
      ext = 'jpg';
    }
    File extFile = File(joinAll([
      (Directory(join((await getTemporaryDirectory()).path, 'cover_ext_cache')))
          .path,
      musicId
    ]));
    File cacheFile = File(joinAll([
      (Directory(join((await getTemporaryDirectory()).path, 'cover_cache')))
          .path,
      musicId + "." + ext
    ]));
    if (!extFile.existsSync()) {
      extFile = await extFile.create(recursive: true);
    }
    if (!cacheFile.existsSync()) {
      cacheFile = await cacheFile.create(recursive: true);
    }
    await extFile.writeAsString(ext);
    await cacheFile.writeAsBytes(by);
    return cacheFile;
  }

  Future<File> getCover(String musicId) async {
    File extFile = File(joinAll([
      (Directory(join((await getTemporaryDirectory()).path, 'cover_ext_cache')))
          .path,
      musicId
    ]));
    String ext = 'png';
    if (extFile.existsSync()) {
      ext = await extFile.readAsString();
    }
    if (ext.trim() == '') {
      ext = 'png';
    }
    File cacheFile = File(joinAll([
      (Directory(join((await getTemporaryDirectory()).path, 'cover_cache')))
          .path,
      musicId + "." + ext
    ]));
    return cacheFile;
  }

  Future<File> getDefaultCover() async {
    File defaultCoverFile = File(joinAll([
      (Directory(
          join((await getApplicationDocumentsDirectory()).path, 'cover')))
          .path,
      "default_cover.jpg"
    ]));
    if (!defaultCoverFile.existsSync()) {
      defaultCoverFile = await defaultCoverFile.create(recursive: true);
      ByteData data = await rootBundle.load("asserts/images/default_cover.jpg");
      List<int> bytes =
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await defaultCoverFile.writeAsBytes(bytes);
    }
    return defaultCoverFile;
  }

  Future<bool> deleteCover(String musicId) async {
    LogHelper.get().info('start delete cache cover $musicId');
    if (musicId == '') {
      return false;
    }
    File extFile = File(joinAll([
      (Directory(join((await getTemporaryDirectory()).path, 'cover_ext_cache')))
          .path,
      musicId
    ]));
    if (!extFile.existsSync()) {
      return false;
    }
    String ext = await extFile.readAsString();
    if (ext.trim() == '') {
      ext = 'png';
    }
    File cacheFile = File(joinAll([
      (Directory(join((await getTemporaryDirectory()).path, 'cover_cache')))
          .path,
      musicId + "." + ext
    ]));
    if (cacheFile.existsSync()) {
      await cacheFile.delete();
      await extFile.delete();
      return true;
    }
    await extFile.delete();
    return false;
  }

  Future<bool> deleteMusicCacheByMusicId(String musicId) async {
    Uri uri = Uri.parse(HttpHelper.get().getMusicUrl(musicId));
    File cacheFile = File(joinAll([
      (Directory(
              join((await getTemporaryDirectory()).path, 'just_audio_cache')))
          .path,
      'remote',
      sha256.convert(utf8.encode(uri.toString())).toString() +
          extension(uri.path),
    ]));
    LogHelper.get().debug('即将删除音乐缓存文件：$cacheFile');
    if (cacheFile.existsSync()) {
      try {
        cacheFile.deleteSync();
        return true;
      } catch (e) {
        LogHelper.get().warn('删除音乐缓存文件失败', e);
        return false;
      }
    } else {
      return false;
    }
  }

  Future<void> setEnableMusicCache(bool enable) async {
    _enableMusicCache = enable;
    _sharedPreferences.setBool(_enableMusicCacheKey, enable);
    notifyListeners();
  }

  Future<void> setEnableCoverCache(bool enable) async {
    _enableCoverCache = enable;
    _sharedPreferences.setBool(_enableCoverCacheKey, enable);
    notifyListeners();
  }

  Future<void> setEnableLyricCache(bool enable) async {
    _enableLyricCache = enable;
    _sharedPreferences.setBool(_enableLyricCacheKey, enable);
    notifyListeners();
  }
}
