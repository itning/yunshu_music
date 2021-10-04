import 'dart:developer';

import 'package:sqflite/sqflite.dart';
import 'package:yunshu_music/net/model/music_entity.dart';

class CacheModel {
  static CacheModel? _instance;

  static CacheModel get() {
    _instance ??= CacheModel();
    return _instance!;
  }

  late Database _database;

  Future<void> init() async {
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
    log('start cache play add one');
    return await _database.transaction((txn) async {
      return await txn.rawInsert(
          'INSERT INTO play_cache (musicId,lyricId,name,singer,type) VALUES ("${list.musicId}","${list.lyricId}","${list.name}","${list.singer}",${list.type} );');
    });
  }

  Future<int> cachePlayList(List<MusicDataContent> list) async {
    log('start cache play list');
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
      log('SQL>>>INSERT INTO play_cache (musicId,lyricId,name,singer,type) VALUES $stringBuffer;');
      return await txn.rawInsert(
          "INSERT INTO play_cache (musicId,lyricId,name,singer,type) VALUES $stringBuffer;");
    });
  }

  Future<List<MusicDataContent>> getPlayList() async {
    log('get play list from cache');
    List<Map<String, Object?>> list = await _database.query('play_cache');
    if (list.isEmpty) {
      return [];
    }
    return list.map((e) => MusicDataContent().fromJson(e)).toList();
  }

  Future<int> cacheMusicList(List<MusicDataContent> list) async {
    log('start cache music list');
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
      await txn.rawDelete('DELETE FROM list_cache');
      log('SQL>>>INSERT INTO list_cache (musicId,lyricId,name,singer,type) VALUES $stringBuffer;');
      return await txn.rawInsert(
          "INSERT INTO list_cache (musicId,lyricId,name,singer,type) VALUES $stringBuffer;");
    });
  }

  Future<List<MusicDataContent>> getMusicList() async {
    log('get music list from cache');
    List<Map<String, Object?>> list = await _database.query('list_cache');
    if (list.isEmpty) {
      return [];
    }
    return list.map((e) => MusicDataContent().fromJson(e)).toList();
  }

  Future<int> cacheLyric(String lyricId, String? content) async {
    log('start cache lyric');
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

  Future<String?> getLyric(String lyricId) async {
    log('get lyric from cache $lyricId');
    List<Map<String, Object?>> list = await _database
        .rawQuery('select * from lyric_cache where lyricId = "$lyricId";');
    if (list.isEmpty) {
      return null;
    }
    return list[0]['data']?.toString();
  }

  Future<int> cacheCover(String musicId, String? base64) async {
    log('start cache cover');
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
    log('get cover from cache $musicId');
    List<Map<String, Object?>> list = await _database
        .rawQuery('select * from cover_cache where musicId = "$musicId";');
    if (list.isEmpty) {
      return null;
    }
    return list[0]['base64']?.toString();
  }
}
