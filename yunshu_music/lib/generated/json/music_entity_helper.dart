import 'package:yunshu_music/net/model/music_entity.dart';

musicEntityFromJson(MusicEntity data, Map<String, dynamic> json) {
	if (json['code'] != null) {
		data.code = json['code'] is String
				? int.tryParse(json['code'])
				: json['code'].toInt();
	}
	if (json['msg'] != null) {
		data.msg = json['msg'].toString();
	}
	if (json['data'] != null) {
		data.data = MusicData().fromJson(json['data']);
	}
	return data;
}

Map<String, dynamic> musicEntityToJson(MusicEntity entity) {
	final Map<String, dynamic> data = new Map<String, dynamic>();
	data['code'] = entity.code;
	data['msg'] = entity.msg;
	data['data'] = entity.data?.toJson();
	return data;
}

musicDataFromJson(MusicData data, Map<String, dynamic> json) {
	if (json['content'] != null) {
		data.content = (json['content'] as List).map((v) => MusicDataContent().fromJson(v)).toList();
	}
	if (json['pageable'] != null) {
		data.pageable = MusicDataPageable().fromJson(json['pageable']);
	}
	if (json['last'] != null) {
		data.last = json['last'];
	}
	if (json['totalPages'] != null) {
		data.totalPages = json['totalPages'] is String
				? int.tryParse(json['totalPages'])
				: json['totalPages'].toInt();
	}
	if (json['totalElements'] != null) {
		data.totalElements = json['totalElements'] is String
				? int.tryParse(json['totalElements'])
				: json['totalElements'].toInt();
	}
	if (json['sort'] != null) {
		data.sort = MusicDataSort().fromJson(json['sort']);
	}
	if (json['first'] != null) {
		data.first = json['first'];
	}
	if (json['number'] != null) {
		data.number = json['number'] is String
				? int.tryParse(json['number'])
				: json['number'].toInt();
	}
	if (json['numberOfElements'] != null) {
		data.numberOfElements = json['numberOfElements'] is String
				? int.tryParse(json['numberOfElements'])
				: json['numberOfElements'].toInt();
	}
	if (json['size'] != null) {
		data.size = json['size'] is String
				? int.tryParse(json['size'])
				: json['size'].toInt();
	}
	if (json['empty'] != null) {
		data.empty = json['empty'];
	}
	return data;
}

Map<String, dynamic> musicDataToJson(MusicData entity) {
	final Map<String, dynamic> data = new Map<String, dynamic>();
	data['content'] =  entity.content?.map((v) => v.toJson())?.toList();
	data['pageable'] = entity.pageable?.toJson();
	data['last'] = entity.last;
	data['totalPages'] = entity.totalPages;
	data['totalElements'] = entity.totalElements;
	data['sort'] = entity.sort?.toJson();
	data['first'] = entity.first;
	data['number'] = entity.number;
	data['numberOfElements'] = entity.numberOfElements;
	data['size'] = entity.size;
	data['empty'] = entity.empty;
	return data;
}

musicDataContentFromJson(MusicDataContent data, Map<String, dynamic> json) {
	if (json['musicId'] != null) {
		data.musicId = json['musicId'].toString();
	}
	if (json['name'] != null) {
		data.name = json['name'].toString();
	}
	if (json['singer'] != null) {
		data.singer = json['singer'].toString();
	}
	if (json['lyricId'] != null) {
		data.lyricId = json['lyricId'].toString();
	}
	if (json['type'] != null) {
		data.type = json['type'] is String
				? int.tryParse(json['type'])
				: json['type'].toInt();
	}
	if (json['musicUri'] != null) {
		data.musicUri = json['musicUri'].toString();
	}
	if (json['lyricUri'] != null) {
		data.lyricUri = json['lyricUri'].toString();
	}
	if (json['coverUri'] != null) {
		data.coverUri = json['coverUri'].toString();
	}
	return data;
}

Map<String, dynamic> musicDataContentToJson(MusicDataContent entity) {
	final Map<String, dynamic> data = new Map<String, dynamic>();
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

musicDataPageableFromJson(MusicDataPageable data, Map<String, dynamic> json) {
	if (json['sort'] != null) {
		data.sort = MusicDataPageableSort().fromJson(json['sort']);
	}
	if (json['pageNumber'] != null) {
		data.pageNumber = json['pageNumber'] is String
				? int.tryParse(json['pageNumber'])
				: json['pageNumber'].toInt();
	}
	if (json['pageSize'] != null) {
		data.pageSize = json['pageSize'] is String
				? int.tryParse(json['pageSize'])
				: json['pageSize'].toInt();
	}
	if (json['offset'] != null) {
		data.offset = json['offset'] is String
				? int.tryParse(json['offset'])
				: json['offset'].toInt();
	}
	if (json['paged'] != null) {
		data.paged = json['paged'];
	}
	if (json['unpaged'] != null) {
		data.unpaged = json['unpaged'];
	}
	return data;
}

Map<String, dynamic> musicDataPageableToJson(MusicDataPageable entity) {
	final Map<String, dynamic> data = new Map<String, dynamic>();
	data['sort'] = entity.sort?.toJson();
	data['pageNumber'] = entity.pageNumber;
	data['pageSize'] = entity.pageSize;
	data['offset'] = entity.offset;
	data['paged'] = entity.paged;
	data['unpaged'] = entity.unpaged;
	return data;
}

musicDataPageableSortFromJson(MusicDataPageableSort data, Map<String, dynamic> json) {
	if (json['unsorted'] != null) {
		data.unsorted = json['unsorted'];
	}
	if (json['sorted'] != null) {
		data.sorted = json['sorted'];
	}
	if (json['empty'] != null) {
		data.empty = json['empty'];
	}
	return data;
}

Map<String, dynamic> musicDataPageableSortToJson(MusicDataPageableSort entity) {
	final Map<String, dynamic> data = new Map<String, dynamic>();
	data['unsorted'] = entity.unsorted;
	data['sorted'] = entity.sorted;
	data['empty'] = entity.empty;
	return data;
}

musicDataSortFromJson(MusicDataSort data, Map<String, dynamic> json) {
	if (json['unsorted'] != null) {
		data.unsorted = json['unsorted'];
	}
	if (json['sorted'] != null) {
		data.sorted = json['sorted'];
	}
	if (json['empty'] != null) {
		data.empty = json['empty'];
	}
	return data;
}

Map<String, dynamic> musicDataSortToJson(MusicDataSort entity) {
	final Map<String, dynamic> data = new Map<String, dynamic>();
	data['unsorted'] = entity.unsorted;
	data['sorted'] = entity.sorted;
	data['empty'] = entity.empty;
	return data;
}