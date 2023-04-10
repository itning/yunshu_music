import 'package:yunshu_music/generated/json/base/json_convert_content.dart';
import 'package:yunshu_music/net/model/search_result_entity.dart';

SearchResultEntity $SearchResultEntityFromJson(Map<String, dynamic> json) {
  final SearchResultEntity searchResultEntity = SearchResultEntity();
  final int? code = jsonConvert.convert<int>(json['code']);
  if (code != null) {
    searchResultEntity.code = code;
  }
  final String? msg = jsonConvert.convert<String>(json['msg']);
  if (msg != null) {
    searchResultEntity.msg = msg;
  }
  final List<SearchResultData>? data =
      jsonConvert.convertListNotNull<SearchResultData>(json['data']);
  if (data != null) {
    searchResultEntity.data = data;
  }
  return searchResultEntity;
}

Map<String, dynamic> $SearchResultEntityToJson(SearchResultEntity entity) {
  final Map<String, dynamic> data = <String, dynamic>{};
  data['code'] = entity.code;
  data['msg'] = entity.msg;
  data['data'] = entity.data?.map((v) => v.toJson()).toList();
  return data;
}

SearchResultData $SearchResultDataFromJson(Map<String, dynamic> json) {
  final SearchResultData searchResultData = SearchResultData();
  final String? musicId = jsonConvert.convert<String>(json['musicId']);
  if (musicId != null) {
    searchResultData.musicId = musicId;
  }
  final String? name = jsonConvert.convert<String>(json['name']);
  if (name != null) {
    searchResultData.name = name;
  }
  final String? singer = jsonConvert.convert<String>(json['singer']);
  if (singer != null) {
    searchResultData.singer = singer;
  }
  final String? lyricId = jsonConvert.convert<String>(json['lyricId']);
  if (lyricId != null) {
    searchResultData.lyricId = lyricId;
  }
  final int? type = jsonConvert.convert<int>(json['type']);
  if (type != null) {
    searchResultData.type = type;
  }
  final String? musicUri = jsonConvert.convert<String>(json['musicUri']);
  if (musicUri != null) {
    searchResultData.musicUri = musicUri;
  }
  final String? lyricUri = jsonConvert.convert<String>(json['lyricUri']);
  if (lyricUri != null) {
    searchResultData.lyricUri = lyricUri;
  }
  final String? coverUri = jsonConvert.convert<String>(json['coverUri']);
  if (coverUri != null) {
    searchResultData.coverUri = coverUri;
  }
  final List<String>? highlightFields =
      jsonConvert.convertListNotNull<String>(json['highlightFields']);
  if (highlightFields != null) {
    searchResultData.highlightFields = highlightFields;
  }
  return searchResultData;
}

Map<String, dynamic> $SearchResultDataToJson(SearchResultData entity) {
  final Map<String, dynamic> data = <String, dynamic>{};
  data['musicId'] = entity.musicId;
  data['name'] = entity.name;
  data['singer'] = entity.singer;
  data['lyricId'] = entity.lyricId;
  data['type'] = entity.type;
  data['musicUri'] = entity.musicUri;
  data['lyricUri'] = entity.lyricUri;
  data['coverUri'] = entity.coverUri;
  data['highlightFields'] = entity.highlightFields;
  return data;
}
