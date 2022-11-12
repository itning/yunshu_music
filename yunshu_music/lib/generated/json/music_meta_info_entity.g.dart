import 'package:yunshu_music/generated/json/base/json_convert_content.dart';
import 'package:yunshu_music/net/model/music_meta_info_entity.dart';

MusicMetaInfoEntity $MusicMetaInfoEntityFromJson(Map<String, dynamic> json) {
	final MusicMetaInfoEntity musicMetaInfoEntity = MusicMetaInfoEntity();
	final int? code = jsonConvert.convert<int>(json['code']);
	if (code != null) {
		musicMetaInfoEntity.code = code;
	}
	final String? msg = jsonConvert.convert<String>(json['msg']);
	if (msg != null) {
		musicMetaInfoEntity.msg = msg;
	}
	final MusicMetaInfoData? data = jsonConvert.convert<MusicMetaInfoData>(json['data']);
	if (data != null) {
		musicMetaInfoEntity.data = data;
	}
	return musicMetaInfoEntity;
}

Map<String, dynamic> $MusicMetaInfoEntityToJson(MusicMetaInfoEntity entity) {
	final Map<String, dynamic> data = <String, dynamic>{};
	data['code'] = entity.code;
	data['msg'] = entity.msg;
	data['data'] = entity.data?.toJson();
	return data;
}

MusicMetaInfoData $MusicMetaInfoDataFromJson(Map<String, dynamic> json) {
	final MusicMetaInfoData musicMetaInfoData = MusicMetaInfoData();
	final String? title = jsonConvert.convert<String>(json['title']);
	if (title != null) {
		musicMetaInfoData.title = title;
	}
	final List<String>? artists = jsonConvert.convertListNotNull<String>(json['artists']);
	if (artists != null) {
		musicMetaInfoData.artists = artists;
	}
	final String? album = jsonConvert.convert<String>(json['album']);
	if (album != null) {
		musicMetaInfoData.album = album;
	}
	final List<MusicMetaInfoDataCoverPictures>? coverPictures = jsonConvert.convertListNotNull<MusicMetaInfoDataCoverPictures>(json['coverPictures']);
	if (coverPictures != null) {
		musicMetaInfoData.coverPictures = coverPictures;
	}
	return musicMetaInfoData;
}

Map<String, dynamic> $MusicMetaInfoDataToJson(MusicMetaInfoData entity) {
	final Map<String, dynamic> data = <String, dynamic>{};
	data['title'] = entity.title;
	data['artists'] =  entity.artists;
	data['album'] = entity.album;
	data['coverPictures'] =  entity.coverPictures?.map((v) => v.toJson()).toList();
	return data;
}

MusicMetaInfoDataCoverPictures $MusicMetaInfoDataCoverPicturesFromJson(Map<String, dynamic> json) {
	final MusicMetaInfoDataCoverPictures musicMetaInfoDataCoverPictures = MusicMetaInfoDataCoverPictures();
	final String? base64 = jsonConvert.convert<String>(json['base64']);
	if (base64 != null) {
		musicMetaInfoDataCoverPictures.base64 = base64;
	}
	final String? mimeType = jsonConvert.convert<String>(json['mimeType']);
	if (mimeType != null) {
		musicMetaInfoDataCoverPictures.mimeType = mimeType;
	}
	final String? description = jsonConvert.convert<String>(json['description']);
	if (description != null) {
		musicMetaInfoDataCoverPictures.description = description;
	}
	final String? imageUrl = jsonConvert.convert<String>(json['imageUrl']);
	if (imageUrl != null) {
		musicMetaInfoDataCoverPictures.imageUrl = imageUrl;
	}
	final int? pictureType = jsonConvert.convert<int>(json['pictureType']);
	if (pictureType != null) {
		musicMetaInfoDataCoverPictures.pictureType = pictureType;
	}
	final bool? linked = jsonConvert.convert<bool>(json['linked']);
	if (linked != null) {
		musicMetaInfoDataCoverPictures.linked = linked;
	}
	return musicMetaInfoDataCoverPictures;
}

Map<String, dynamic> $MusicMetaInfoDataCoverPicturesToJson(MusicMetaInfoDataCoverPictures entity) {
	final Map<String, dynamic> data = <String, dynamic>{};
	data['base64'] = entity.base64;
	data['mimeType'] = entity.mimeType;
	data['description'] = entity.description;
	data['imageUrl'] = entity.imageUrl;
	data['pictureType'] = entity.pictureType;
	data['linked'] = entity.linked;
	return data;
}