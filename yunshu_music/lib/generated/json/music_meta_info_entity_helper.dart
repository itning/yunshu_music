import 'package:yunshu_music/net/model/music_meta_info_entity.dart';

musicMetaInfoEntityFromJson(MusicMetaInfoEntity data, Map<String, dynamic> json) {
	if (json['code'] != null) {
		data.code = json['code'] is String
				? int.tryParse(json['code'])
				: json['code'].toInt();
	}
	if (json['msg'] != null) {
		data.msg = json['msg'].toString();
	}
	if (json['data'] != null) {
		data.data = MusicMetaInfoData().fromJson(json['data']);
	}
	return data;
}

Map<String, dynamic> musicMetaInfoEntityToJson(MusicMetaInfoEntity entity) {
	final Map<String, dynamic> data = new Map<String, dynamic>();
	data['code'] = entity.code;
	data['msg'] = entity.msg;
	data['data'] = entity.data?.toJson();
	return data;
}

musicMetaInfoDataFromJson(MusicMetaInfoData data, Map<String, dynamic> json) {
	if (json['title'] != null) {
		data.title = json['title'].toString();
	}
	if (json['artists'] != null) {
		data.artists = (json['artists'] as List).map((v) => v.toString()).toList().cast<String>();
	}
	if (json['album'] != null) {
		data.album = json['album'].toString();
	}
	if (json['coverPictures'] != null) {
		data.coverPictures = (json['coverPictures'] as List).map((v) => MusicMetaInfoDataCoverPictures().fromJson(v)).toList();
	}
	return data;
}

Map<String, dynamic> musicMetaInfoDataToJson(MusicMetaInfoData entity) {
	final Map<String, dynamic> data = new Map<String, dynamic>();
	data['title'] = entity.title;
	data['artists'] = entity.artists;
	data['album'] = entity.album;
	data['coverPictures'] =  entity.coverPictures?.map((v) => v.toJson())?.toList();
	return data;
}

musicMetaInfoDataCoverPicturesFromJson(MusicMetaInfoDataCoverPictures data, Map<String, dynamic> json) {
	if (json['base64'] != null) {
		data.base64 = json['base64'].toString();
	}
	if (json['mimeType'] != null) {
		data.mimeType = json['mimeType'].toString();
	}
	if (json['description'] != null) {
		data.description = json['description'].toString();
	}
	if (json['imageUrl'] != null) {
		data.imageUrl = json['imageUrl'].toString();
	}
	if (json['pictureType'] != null) {
		data.pictureType = json['pictureType'] is String
				? int.tryParse(json['pictureType'])
				: json['pictureType'].toInt();
	}
	if (json['linked'] != null) {
		data.linked = json['linked'];
	}
	return data;
}

Map<String, dynamic> musicMetaInfoDataCoverPicturesToJson(MusicMetaInfoDataCoverPictures entity) {
	final Map<String, dynamic> data = new Map<String, dynamic>();
	data['base64'] = entity.base64;
	data['mimeType'] = entity.mimeType;
	data['description'] = entity.description;
	data['imageUrl'] = entity.imageUrl;
	data['pictureType'] = entity.pictureType;
	data['linked'] = entity.linked;
	return data;
}