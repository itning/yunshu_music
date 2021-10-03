import 'package:dio/dio.dart';
import 'package:flutter_rest_template/flutter_rest_template.dart';
import 'package:flutter_rest_template/impl/dio_client_http_request_factory.dart';
import 'package:flutter_rest_template/response_entity.dart';
import 'package:yunshu_music/net/model/music_entity.dart';
import 'package:yunshu_music/net/model/music_meta_info_entity.dart';

class HttpHelper {
  static HttpHelper? _instance;

  static HttpHelper get() {
    _instance ??= HttpHelper._();
    return _instance!;
  }

  late final RestTemplate _restTemplate;

  late final Dio _dio;

  final String baseUrl = "http://49.235.109.242:8888";

  HttpHelper._() {
    _dio = Dio();
    _restTemplate = RestTemplate(DioClientHttpRequestFactory(_dio));
  }

  Future<ResponseEntity<MusicEntity>> getMusic() async {
    ResponseEntity<Map<String, dynamic>> responseEntity =
        await _restTemplate.getForMapEntry("$baseUrl/music?size=5000");
    Map<String, dynamic>? body = responseEntity.body;
    if (null != body) {
      MusicEntity musicEntity = MusicEntity().fromJson(body);
      return ResponseEntity(responseEntity.status,
          body: musicEntity, headers: responseEntity.headers);
    } else {
      return ResponseEntity(responseEntity.status,
          headers: responseEntity.headers);
    }
  }

  Future<ResponseEntity<MusicMetaInfoEntity>> getMetaInfo(
      String musicId) async {
    ResponseEntity<Map<String, dynamic>> responseEntity = await _restTemplate
        .getForMapEntry("$baseUrl/music/metaInfo?id=$musicId");
    Map<String, dynamic>? body = responseEntity.body;
    if (null != body) {
      MusicMetaInfoEntity musicEntity = MusicMetaInfoEntity().fromJson(body);
      return ResponseEntity(responseEntity.status,
          body: musicEntity, headers: responseEntity.headers);
    } else {
      return ResponseEntity(responseEntity.status,
          headers: responseEntity.headers);
    }
  }

  Future<String?> getLyric(String lyricId) async {
    Response<String> response =
        await _dio.get<String>('$baseUrl/file/lyric?id=$lyricId');
    print('获取歌词：$baseUrl/file/lyric?id=$lyricId');
    return response.data;
  }

  String getMusicUrl(String musicId) {
    return "$baseUrl/file?id=$musicId";
  }
}
