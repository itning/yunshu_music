import 'dart:convert';

import 'package:yunshu_music/generated/json/base/json_field.dart';
import 'package:yunshu_music/generated/json/music_entity.g.dart';

@JsonSerializable()
class MusicEntity {
  int? code;
  String? msg;
  List<MusicData>? data;

  MusicEntity();

  factory MusicEntity.fromJson(Map<String, dynamic> json) =>
      $MusicEntityFromJson(json);

  Map<String, dynamic> toJson() => $MusicEntityToJson(this);

  @override
  String toString() {
    return jsonEncode(this);
  }
}

@JsonSerializable()
class MusicData {
  String? musicId;
  String? name;
  String? singer;
  String? lyricId;
  int? type;
  String? musicUri;
  String? lyricUri;
  String? coverUri;
  String? musicDownloadUri;

  MusicData();

  factory MusicData.fromJson(Map<String, dynamic> json) =>
      $MusicDataFromJson(json);

  Map<String, dynamic> toJson() => $MusicDataToJson(this);

  @override
  String toString() {
    return jsonEncode(this);
  }
}
