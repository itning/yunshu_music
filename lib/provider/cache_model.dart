import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
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
      // 正在播放的列表 缓存
      await db.execute(
          'CREATE TABLE play_cache (musicId TEXT PRIMARY KEY, lyricId TEXT, name TEXT, singer TEXT, type INTEGER)');
      // 音乐 缓存
      await db.execute(
          'CREATE TABLE music_cache (musicId TEXT PRIMARY KEY, data BLOB)');
      // 歌词 缓存
      await db.execute(
          'CREATE TABLE lyric_cache (lyricId TEXT PRIMARY KEY, data TEXT)');
      // 封面 缓存
      await db.execute(
          'CREATE TABLE cover_cache (musicId TEXT PRIMARY KEY, base64 TEXT)');
    });
  }

  Future<int> cachePlayListAddOne(MusicDataContent list) async {
    LogHelper.get().info('start cache play add one');
    return await _database.transaction((txn) async {
      return await txn.rawInsert(
          'INSERT INTO play_cache (musicId,lyricId,name,singer,type) VALUES ("${list.musicId}","${list.lyricId}","${list.name}","${list.singer}",${list.type} );');
    });
  }

  Future<int> cachePlayList(List<MusicDataContent> list) async {
    LogHelper.get().info('start cache play list');
    return await _database.transaction((txn) async {
      // int? count = Sqflite.firstIntValue(await txn.rawQuery('select count(*) from list_cache where '));
      StringBuffer stringBuffer = StringBuffer();
      for (int i = 0; i < list.length; i++) {
        MusicDataContent item = list[i];
        stringBuffer.write('(');
        stringBuffer.write('"${item.musicId}"');
        stringBuffer.write(',');
        stringBuffer.write('"${item.lyricId}"');
        stringBuffer.write(',');
        stringBuffer.write('"${item.name}"');
        stringBuffer.write(',');
        stringBuffer.write('"${item.singer}"');
        stringBuffer.write(',');
        stringBuffer.write("${item.type}");
        if (i + 1 != list.length) {
          stringBuffer.write('), ');
        } else {
          stringBuffer.write(')');
        }
      }
      await txn.rawDelete('DELETE FROM play_cache');
      LogHelper.get().info(
          'SQL:INSERT INTO play_cache (musicId,lyricId,name,singer,type) VALUES $stringBuffer;');
      return await txn.rawInsert(
          "INSERT INTO play_cache (musicId,lyricId,name,singer,type) VALUES $stringBuffer;");
    });
  }

  Future<List<MusicDataContent>> getPlayList() async {
    LogHelper.get().info('get play list from cache');
    List<Map<String, Object?>> list = await _database.query('play_cache');
    if (list.isEmpty) {
      return [];
    }
    return list.map((e) => MusicDataContent().fromJson(e)).toList();
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

  Future<int> cacheCover(String musicId, String? base64) async {
    if (!_enableCoverCache) {
      return 0;
    }
    LogHelper.get().info('start cache cover');
    if (base64 == null || base64 == '') {
      return 0;
    }
    return await _database.transaction((txn) async {
      await txn
          .rawDelete('DELETE FROM cover_cache where musicId = ?', [musicId]);
      return await txn.rawInsert(
          'INSERT INTO cover_cache (musicId,base64) VALUES ("$musicId","$base64");');
    });
  }

  Future<String?> getCover(String musicId) async {
    if (!_enableCoverCache) {
      return null;
    }
    LogHelper.get().info('get cover from cache $musicId');
    List<Map<String, Object?>> list = await _database
        .rawQuery('select * from cover_cache where musicId = "$musicId";');
    if (list.isEmpty) {
      return null;
    }
    return list[0]['base64']?.toString();
  }

  Future<int> deleteCover(String musicId) async {
    LogHelper.get().info('start delete cache cover $musicId');
    if (musicId == '') {
      return 0;
    }
    return await _database
        .rawDelete('delete from cover_cache where musicId = ?', [musicId]);
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
