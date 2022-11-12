import 'package:yunshu_music/generated/json/base/json_field.dart';
import 'package:yunshu_music/generated/json/music_meta_info_entity.g.dart';


@JsonSerializable()
class MusicMetaInfoEntity {

	MusicMetaInfoEntity();

	factory MusicMetaInfoEntity.fromJson(Map<String, dynamic> json) => $MusicMetaInfoEntityFromJson(json);

	Map<String, dynamic> toJson() => $MusicMetaInfoEntityToJson(this);

  int? code;
  String? msg;
  MusicMetaInfoData? data;
}

@JsonSerializable()
class MusicMetaInfoData {

	MusicMetaInfoData();

	factory MusicMetaInfoData.fromJson(Map<String, dynamic> json) => $MusicMetaInfoDataFromJson(json);

	Map<String, dynamic> toJson() => $MusicMetaInfoDataToJson(this);

  String? title;
  List<String>? artists;
  String? album;
  List<MusicMetaInfoDataCoverPictures>? coverPictures;
}

@JsonSerializable()
class MusicMetaInfoDataCoverPictures     {

	MusicMetaInfoDataCoverPictures();

	factory MusicMetaInfoDataCoverPictures.fromJson(Map<String, dynamic> json) => $MusicMetaInfoDataCoverPicturesFromJson(json);

	Map<String, dynamic> toJson() => $MusicMetaInfoDataCoverPicturesToJson(this);

  String? base64;
  String? mimeType;
  String? description;
  String? imageUrl;
  int? pictureType;
  bool? linked;
}
