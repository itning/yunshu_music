import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yunshu_music/net/http_helper.dart';
import 'package:yunshu_music/util/common_utils.dart';

/// https://github.com/lau1944/just_audio_cache
extension AudioPlayerExtension on AudioPlayer {
  static SharedPreferences? _sp;

  /// Check if the file corresponds the url exists in local
  Future<String?> existedInLocal({required String url}) async {
    _sp ??= await SharedPreferences.getInstance();

    return _sp!.getString(getCacheKey(url));
  }

  /// Get audio file cache path
  Future<String?> getCachedPath({required String url}) async {
    _sp ??= await SharedPreferences.getInstance();

    return _sp!.getString(getCacheKey(url));
  }

  /// Get audio from local if exist, otherwise download from network
  /// [url] is your audio source, a unique key that represents the stored file path,
  /// [path] the storage path you want to save your cache
  /// [pushIfNotExisted] if true, when the file not exists, would download the file and push in cache
  /// [excludeCallback] a callback function where you can specify which file you don't want to be cached,
  ///  (return `true` if we want to exclude the specific source)
  Future<Duration?> dynamicSet({
    required String url,
    String? path,
    bool pushIfNotExisted = true,
    bool excludeCallback(url)?,
    bool preload = true,
  }) async {
    _sp ??= await SharedPreferences.getInstance();

    if (excludeCallback != null) {
      pushIfNotExisted = excludeCallback(url);
    }

    final dirPath = path ?? (await _openDir()).path;
    // File check
    String? cachePath = await existedInLocal(url: url);
    bool exist = checkFileExist(cachePath);
    if (null != cachePath && exist) {
      // existed, play from local file
      LogHelper.get().info('缓存中存在，从缓存中设置音频源 $url $cachePath');
      try {
        return await setFilePath(_sp!.getString(url)!, preload: preload);
      } catch (e) {
        LogHelper.get().error('从缓存中设置音频失败', e);
      }
    }

    if (null != cachePath && !exist) {
      _sp ??= await SharedPreferences.getInstance();
      await _sp!.remove(getCacheKey(url));
    }

    final duration = await setUrl(url, preload: preload);

    // download to cache after setUrl in order to show the audio buffer state
    if (pushIfNotExisted) {
      final key = getCacheKey(url);
      HttpHelper.get().download(url, dirPath + '/' + key).then((storedPath) {
        if (storedPath != null) {
          _sp!.setString(url, storedPath.path);
        }
      });
    }

    return duration;
  }

  /// Cache a collection of audio source
  /// [sources] target sources for your playlist
  /// [path] The dir path where sources store
  /// [excluded] the sources you don't want to save in storage
  Future<List<Duration?>> dynamicSetAll(
    List<String> sources, [
    String? path,
    List<String>? excluded,
  ]) async {
    const durations = <Duration?>[];
    for (final url in sources) {
      durations.add(
        await dynamicSet(
          url: url,
          path: path,
          excludeCallback: (url) => excluded != null && excluded.contains(url),
        ),
      );
    }
    return durations;
  }

  Future<void> cacheFile({required String url, String? path}) async {
    final dirPath = path ?? (await _openDir()).path;
    final storedPath = await HttpHelper.get().download(url, dirPath);
    if (storedPath != null) {
      _sp!.setString(url, storedPath.path);
    }
  }

  Future<void> playFromFile({required String filePath}) async {
    await setFilePath(filePath);
    return await play();
  }

  /*Future<bool> _isKeyExisted(String key) async {
    if (_sp == null) _sp = await SharedPreferences.getInstance();

    return _sp!.getString(key) != null;
  }*/

  Future<Directory> _openDir() async {
    final dir = await getTemporaryDirectory();
    final Directory targetDir = Directory(dir.path + '/audio_cache');
    if (!targetDir.existsSync()) {
      targetDir.createSync();
    }
    return targetDir;
  }

  bool checkFileExist(String? path) {
    if (null == path) {
      return false;
    }
    return File(path).existsSync();
  }

  String getCacheKey(String url) {
    // var bytes = utf8.encode(url);
    // var base64Str = base64.encode(bytes);
    String musicId = Uri.parse(url).queryParameters['id']!;
    return musicId;
  }
}
