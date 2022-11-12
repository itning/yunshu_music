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
	final MusicData? data = jsonConvert.convert<MusicData>(json['data']);
	if (data != null) {
		musicEntity.data = data;
	}
	return musicEntity;
}

Map<String, dynamic> $MusicEntityToJson(MusicEntity entity) {
	final Map<String, dynamic> data = <String, dynamic>{};
	data['code'] = entity.code;
	data['msg'] = entity.msg;
	data['data'] = entity.data?.toJson();
	return data;
}

MusicData $MusicDataFromJson(Map<String, dynamic> json) {
	final MusicData musicData = MusicData();
	final List<MusicDataContent>? content = jsonConvert.convertListNotNull<MusicDataContent>(json['content']);
	if (content != null) {
		musicData.content = content;
	}
	final MusicDataPageable? pageable = jsonConvert.convert<MusicDataPageable>(json['pageable']);
	if (pageable != null) {
		musicData.pageable = pageable;
	}
	final bool? last = jsonConvert.convert<bool>(json['last']);
	if (last != null) {
		musicData.last = last;
	}
	final int? totalPages = jsonConvert.convert<int>(json['totalPages']);
	if (totalPages != null) {
		musicData.totalPages = totalPages;
	}
	final int? totalElements = jsonConvert.convert<int>(json['totalElements']);
	if (totalElements != null) {
		musicData.totalElements = totalElements;
	}
	final MusicDataSort? sort = jsonConvert.convert<MusicDataSort>(json['sort']);
	if (sort != null) {
		musicData.sort = sort;
	}
	final bool? first = jsonConvert.convert<bool>(json['first']);
	if (first != null) {
		musicData.first = first;
	}
	final int? number = jsonConvert.convert<int>(json['number']);
	if (number != null) {
		musicData.number = number;
	}
	final int? numberOfElements = jsonConvert.convert<int>(json['numberOfElements']);
	if (numberOfElements != null) {
		musicData.numberOfElements = numberOfElements;
	}
	final int? size = jsonConvert.convert<int>(json['size']);
	if (size != null) {
		musicData.size = size;
	}
	final bool? empty = jsonConvert.convert<bool>(json['empty']);
	if (empty != null) {
		musicData.empty = empty;
	}
	return musicData;
}

Map<String, dynamic> $MusicDataToJson(MusicData entity) {
	final Map<String, dynamic> data = <String, dynamic>{};
	data['content'] =  entity.content?.map((v) => v.toJson()).toList();
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

MusicDataContent $MusicDataContentFromJson(Map<String, dynamic> json) {
	final MusicDataContent musicDataContent = MusicDataContent();
	final String? musicId = jsonConvert.convert<String>(json['musicId']);
	if (musicId != null) {
		musicDataContent.musicId = musicId;
	}
	final String? name = jsonConvert.convert<String>(json['name']);
	if (name != null) {
		musicDataContent.name = name;
	}
	final String? singer = jsonConvert.convert<String>(json['singer']);
	if (singer != null) {
		musicDataContent.singer = singer;
	}
	final String? lyricId = jsonConvert.convert<String>(json['lyricId']);
	if (lyricId != null) {
		musicDataContent.lyricId = lyricId;
	}
	final int? type = jsonConvert.convert<int>(json['type']);
	if (type != null) {
		musicDataContent.type = type;
	}
	final String? musicUri = jsonConvert.convert<String>(json['musicUri']);
	if (musicUri != null) {
		musicDataContent.musicUri = musicUri;
	}
	final String? lyricUri = jsonConvert.convert<String>(json['lyricUri']);
	if (lyricUri != null) {
		musicDataContent.lyricUri = lyricUri;
	}
	final String? coverUri = jsonConvert.convert<String>(json['coverUri']);
	if (coverUri != null) {
		musicDataContent.coverUri = coverUri;
	}
	return musicDataContent;
}

Map<String, dynamic> $MusicDataContentToJson(MusicDataContent entity) {
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

MusicDataPageable $MusicDataPageableFromJson(Map<String, dynamic> json) {
	final MusicDataPageable musicDataPageable = MusicDataPageable();
	final MusicDataPageableSort? sort = jsonConvert.convert<MusicDataPageableSort>(json['sort']);
	if (sort != null) {
		musicDataPageable.sort = sort;
	}
	final int? pageNumber = jsonConvert.convert<int>(json['pageNumber']);
	if (pageNumber != null) {
		musicDataPageable.pageNumber = pageNumber;
	}
	final int? pageSize = jsonConvert.convert<int>(json['pageSize']);
	if (pageSize != null) {
		musicDataPageable.pageSize = pageSize;
	}
	final int? offset = jsonConvert.convert<int>(json['offset']);
	if (offset != null) {
		musicDataPageable.offset = offset;
	}
	final bool? paged = jsonConvert.convert<bool>(json['paged']);
	if (paged != null) {
		musicDataPageable.paged = paged;
	}
	final bool? unpaged = jsonConvert.convert<bool>(json['unpaged']);
	if (unpaged != null) {
		musicDataPageable.unpaged = unpaged;
	}
	return musicDataPageable;
}

Map<String, dynamic> $MusicDataPageableToJson(MusicDataPageable entity) {
	final Map<String, dynamic> data = <String, dynamic>{};
	data['sort'] = entity.sort?.toJson();
	data['pageNumber'] = entity.pageNumber;
	data['pageSize'] = entity.pageSize;
	data['offset'] = entity.offset;
	data['paged'] = entity.paged;
	data['unpaged'] = entity.unpaged;
	return data;
}

MusicDataPageableSort $MusicDataPageableSortFromJson(Map<String, dynamic> json) {
	final MusicDataPageableSort musicDataPageableSort = MusicDataPageableSort();
	final bool? unsorted = jsonConvert.convert<bool>(json['unsorted']);
	if (unsorted != null) {
		musicDataPageableSort.unsorted = unsorted;
	}
	final bool? sorted = jsonConvert.convert<bool>(json['sorted']);
	if (sorted != null) {
		musicDataPageableSort.sorted = sorted;
	}
	final bool? empty = jsonConvert.convert<bool>(json['empty']);
	if (empty != null) {
		musicDataPageableSort.empty = empty;
	}
	return musicDataPageableSort;
}

Map<String, dynamic> $MusicDataPageableSortToJson(MusicDataPageableSort entity) {
	final Map<String, dynamic> data = <String, dynamic>{};
	data['unsorted'] = entity.unsorted;
	data['sorted'] = entity.sorted;
	data['empty'] = entity.empty;
	return data;
}

MusicDataSort $MusicDataSortFromJson(Map<String, dynamic> json) {
	final MusicDataSort musicDataSort = MusicDataSort();
	final bool? unsorted = jsonConvert.convert<bool>(json['unsorted']);
	if (unsorted != null) {
		musicDataSort.unsorted = unsorted;
	}
	final bool? sorted = jsonConvert.convert<bool>(json['sorted']);
	if (sorted != null) {
		musicDataSort.sorted = sorted;
	}
	final bool? empty = jsonConvert.convert<bool>(json['empty']);
	if (empty != null) {
		musicDataSort.empty = empty;
	}
	return musicDataSort;
}

Map<String, dynamic> $MusicDataSortToJson(MusicDataSort entity) {
	final Map<String, dynamic> data = <String, dynamic>{};
	data['unsorted'] = entity.unsorted;
	data['sorted'] = entity.sorted;
	data['empty'] = entity.empty;
	return data;
}