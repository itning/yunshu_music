import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:tuple/tuple.dart';
import 'package:yunshu_music/util/common_utils.dart';

class HttpHelper {
  static HttpHelper? _instance;

  static HttpHelper get() {
    _instance ??= HttpHelper._();
    return _instance!;
  }

  late final Dio _dio;

  final String baseUrl = "https://music.itning.top";

  HttpHelper._() {
    _dio = Dio();
  }

  CancelToken? _cancelToken;
  CancelToken? _coverCancelToken;
  CancelToken? _lyricCancelToken;
  String? _lastUrl;

  Future<File?> download(String url, String savePath) async {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      LogHelper.get().info('开始取消下载 $_lastUrl');
      _cancelToken!.cancel();
    }
    _lastUrl = url;
    _cancelToken = CancelToken();
    LogHelper.get().debug('开始下载 $url $savePath');
    try {
      int lastDownload = 0;
      Response<List<int>> response = await _dio.get(
        url,
        cancelToken: _cancelToken,
        onReceiveProgress: (int received, int total) {
          if (total != -1) {
            if (received - lastDownload > 2097152) {
              lastDownload = received;
              LogHelper.get().debug(
                  "下载进度: $url $received/$total ${(received / total * 100).toStringAsFixed(0)}%");
            }
          }
        },
        options: Options(
            responseType: ResponseType.bytes,
            validateStatus: (status) {
              if (status == 200) {
                return true;
              } else {
                LogHelper.get().error('下载文件失败,服务器响应码非200 $status');
                return false;
              }
            }),
      );
      if (response.data == null) {
        LogHelper.get().error('下载文件失败,response.data == null');
        return null;
      }
      File file = File(savePath);
      return await file.writeAsBytes(response.data!);
    } catch (e) {
      LogHelper.get().error('下载文件失败 $url $savePath', e);
    } finally {
      LogHelper.get().debug('下载结束 $url $savePath');
      _cancelToken = null;
      _lastUrl = null;
    }
  }

  Future<Response<Map<String, dynamic>>> getMusic() async {
    return await _dio.get<Map<String, dynamic>>("$baseUrl/music?size=5000");
  }

  Future<String?> getLyric(String lyricUri) async {
    LogHelper.get().info('获取歌词：$lyricUri');
    if (null != _lyricCancelToken && !_lyricCancelToken!.isCancelled) {
      LogHelper.get().info('取消上一个获取歌词的请求');
      _lyricCancelToken!.cancel();
    }
    _lyricCancelToken = CancelToken();
    try {
      Response<String> response =
          await _dio.get<String>(lyricUri, cancelToken: _lyricCancelToken);
      _lyricCancelToken = null;
      return response.data;
    } on DioError catch (e) {
      if (e.type == DioErrorType.cancel) {
        LogHelper.get().info('获取歌词请求取消 $lyricUri');
      } else {
        Fluttertoast.showToast(msg: '获取歌词网络异常');
        LogHelper.get().warn('获取歌词网络异常', e);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '获取歌词失败');
      LogHelper.get().error('获取歌词失败', e);
    }
    return null;
  }

  Future<Tuple2<String?, List<int>?>> getCover(String coverUri) async {
    LogHelper.get().info('获取封面：$coverUri');
    if (null != _coverCancelToken && !_coverCancelToken!.isCancelled) {
      LogHelper.get().info('取消上一个获取封面的请求');
      _coverCancelToken!.cancel();
    }
    _coverCancelToken = CancelToken();
    try {
      Response<List<int>> response = await _dio.get<List<int>>(coverUri,
          options: Options(responseType: ResponseType.bytes),
          cancelToken: _coverCancelToken);
      _coverCancelToken = null;
      List<String>? contentTypes = response.headers[Headers.contentTypeHeader];
      String? contentType;
      if (contentTypes != null && contentTypes.isNotEmpty) {
        contentType = contentTypes[0];
      }
      return Tuple2(contentType, response.data);
    } on DioError catch (e) {
      if (e.type == DioErrorType.cancel) {
        LogHelper.get().info('获取封面请求取消 $coverUri');
      } else {
        Fluttertoast.showToast(msg: '获取封面网络异常');
        LogHelper.get().warn('获取封面网络异常', e);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '获取封面失败');
      LogHelper.get().error('获取封面失败', e);
    }
    return const Tuple2(null, null);
  }
}
