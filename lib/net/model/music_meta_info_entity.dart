import 'package:yunshu_music/generated/json/base/json_convert_content.dart';

class MusicMetaInfoEntity with JsonConvert<MusicMetaInfoEntity> {
  int? code;
  String? msg;
  MusicMetaInfoData? data;
}

class MusicMetaInfoData with JsonConvert<MusicMetaInfoData> {
  String? title;
  List<String>? artists;
  String? album;
  List<MusicMetaInfoDataCoverPictures>? coverPictures;
}

class MusicMetaInfoDataCoverPictures
    with JsonConvert<MusicMetaInfoDataCoverPictures> {
  String? base64;
  String? mimeType;
  String? description;
  String? imageUrl;
  int? pictureType;
  bool? linked;
}
