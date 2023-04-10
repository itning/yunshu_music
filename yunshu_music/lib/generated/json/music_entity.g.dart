import 'package:yunshu_music/generated/json/base/json_convert_content.dart';
import 'package:yunshu_music/net/model/music_entity.dart';

MusicEntity $MusicEntityFromJson(Map<String, dynamic> json) {
  final MusicEntity musicEntity = MusicEntity();
  final int? code = jsonConvert.convert<int>(json['code']);
  if (code != null) {
    musicEntity.code = code;
  }
  final String? msg = jsonConvert.convert<String>(json['msg']);
  if (msg != null) {
    musicEntity.msg = msg;
  }
  final List<MusicData>? data =
      jsonConvert.convertListNotNull<MusicData>(json['data']);
  if (data != null) {
    musicEntity.data = data;
  }
  return musicEntity;
}

Map<String, dynamic> $MusicEntityToJson(MusicEntity entity) {
  final Map<String, dynamic> data = <String, dynamic>{};
  data['code'] = entity.code;
  data['msg'] = entity.msg;
  data['data'] = entity.data?.map((v) => v.toJson()).toList();
  return data;
}

MusicData $MusicDataFromJson(Map<String, dynamic> json) {
  final MusicData musicData = MusicData();
  final String? musicId = jsonConvert.convert<String>(json['musicId']);
  if (musicId != null) {
    musicData.musicId = musicId;
  }
  final String? name = jsonConvert.convert<String>(json['name']);
  if (name != null) {
    musicData.name = name;
  }
  final String? singer = jsonConvert.convert<String>(json['singer']);
  if (singer != null) {
    musicData.singer = singer;
  }
  final String? lyricId = jsonConvert.convert<String>(json['lyricId']);
  if (lyricId != null) {
    musicData.lyricId = lyricId;
  }
  final int? type = jsonConvert.convert<int>(json['type']);
  if (type != null) {
    musicData.type = type;
  }
  final String? musicUri = jsonConvert.convert<String>(json['musicUri']);
  if (musicUri != null) {
    musicData.musicUri = musicUri;
  }
  final String? lyricUri = jsonConvert.convert<String>(json['lyricUri']);
  if (lyricUri != null) {
    musicData.lyricUri = lyricUri;
  }
  final String? coverUri = jsonConvert.convert<String>(json['coverUri']);
  if (coverUri != null) {
    musicData.coverUri = coverUri;
  }
  return musicData;
}

Map<String, dynamic> $MusicDataToJson(MusicData entity) {
  final Map<String, dynamic> data = <String, dynamic>{};
  data['musicId'] = entity.musicId;
  data['name'] = entity.name;
  data['singer'] = entity.singer;
  data['lyricId'] = entity.lyricId;
  data['type'] = entity.type;
  data['musicUri'] = entity.musicUri;
  data['lyricUri'] = entity.lyricUri;
  data['coverUri'] = entity.coverUri;
  return data;
}
