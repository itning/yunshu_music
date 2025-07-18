import 'dart:io';

import 'package:dio/dio.dart';
import 'package:music_platform_interface/encryption_tool.dart';
import 'package:tuple/tuple.dart';
import 'package:yunshu_music/provider/login_model.dart';
import 'package:yunshu_music/util/common_utils.dart';

import 'model/search_result_entity.dart';

class HttpHelper {
  static HttpHelper? _instance;

  static HttpHelper get() {
    _instance ??= HttpHelper._();
    return _instance!;
  }

  late final Dio _dio;

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
                "下载进度: $url $received/$total ${(received / total * 100).toStringAsFixed(0)}%",
              );
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
          },
        ),
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
    return null;
  }

  Future<Response<Map<String, dynamic>>> getMusic() async {
    String url = "${LoginModel.get().getBaseUrl()}/music";
    if (LoginModel.get().getEnableAuthorization()) {
      url = sign(
        url: url,
        pkey: LoginModel.get().getSignKey()!,
        signParamName: LoginModel.get().getSignParamName(),
        timeParamName: LoginModel.get().getAuthorizationTimeParamName(),
      );
    }
    return await _dio.get<Map<String, dynamic>>(url);
  }

  Future<String?> getLyric(String lyricUri) async {
    if (LoginModel.get().getEnableAuthorization()) {
      lyricUri = sign(
        url: lyricUri,
        pkey: LoginModel.get().getSignKey()!,
        signParamName: LoginModel.get().getSignParamName(),
        timeParamName: LoginModel.get().getAuthorizationTimeParamName(),
      );
    }
    LogHelper.get().info('获取歌词：$lyricUri');
    if (null != _lyricCancelToken && !_lyricCancelToken!.isCancelled) {
      LogHelper.get().info('取消上一个获取歌词的请求');
      _lyricCancelToken!.cancel();
    }
    _lyricCancelToken = CancelToken();
    try {
      Response<String> response = await _dio.get<String>(
        lyricUri,
        cancelToken: _lyricCancelToken,
      );
      _lyricCancelToken = null;
      return response.data;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        LogHelper.get().info('获取歌词请求取消 $lyricUri');
      } else if (e.response?.statusCode == 404) {
        LogHelper.get().info('该歌曲无歌词 $lyricUri');
      } else {
        LogHelper.get().warn('获取歌词网络异常', e);
      }
    } catch (e) {
      LogHelper.get().error('获取歌词失败', e);
    }
    return null;
  }

  Future<Tuple2<String?, List<int>?>> getCover(String coverUri) async {
    if (LoginModel.get().getEnableAuthorization()) {
      coverUri = sign(
        url: coverUri,
        pkey: LoginModel.get().getSignKey()!,
        signParamName: LoginModel.get().getSignParamName(),
        timeParamName: LoginModel.get().getAuthorizationTimeParamName(),
      );
    }
    LogHelper.get().info('获取封面：$coverUri');
    if (null != _coverCancelToken && !_coverCancelToken!.isCancelled) {
      LogHelper.get().info('取消上一个获取封面的请求');
      _coverCancelToken!.cancel();
    }
    _coverCancelToken = CancelToken();
    try {
      Response<List<int>> response = await _dio.get<List<int>>(
        coverUri,
        options: Options(responseType: ResponseType.bytes),
        cancelToken: _coverCancelToken,
      );
      _coverCancelToken = null;
      List<String>? contentTypes = response.headers[Headers.contentTypeHeader];
      String? contentType;
      if (contentTypes != null && contentTypes.isNotEmpty) {
        contentType = contentTypes[0];
      }
      return Tuple2(contentType, response.data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        LogHelper.get().info('获取封面请求取消 $coverUri');
      } else if (e.response?.statusCode == 404) {
        LogHelper.get().info('该歌曲无封面 $coverUri');
      } else {
        LogHelper.get().warn('获取封面网络异常', e);
      }
    } catch (e) {
      LogHelper.get().error('获取封面失败', e);
    }
    return const Tuple2(null, null);
  }

  Future<SearchResultEntity?> search(String keyword) async {
    keyword = Uri.encodeQueryComponent(keyword);
    try {
      Response<Map<String, dynamic>>
      response = await _dio.get<Map<String, dynamic>>(
        "${LoginModel.get().getBaseUrl()}/music/search_v2?size=5000&keyword=$keyword",
      );
      if (response.data == null) {
        return null;
      }
      SearchResultEntity result = SearchResultEntity.fromJson(response.data!);
      return result;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        LogHelper.get().info('搜索歌词请求取消 $keyword');
      } else if (e.response?.statusCode == 404) {
        LogHelper.get().info('搜索歌词返回404 $keyword');
      } else {
        LogHelper.get().warn('搜索歌词网络异常', e);
      }
    } catch (e) {
      LogHelper.get().error('搜索歌词失败', e);
    }
    return null;
  }
}
