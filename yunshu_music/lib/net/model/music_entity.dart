import 'package:yunshu_music/generated/json/base/json_field.dart';
import 'package:yunshu_music/generated/json/music_entity.g.dart';


@JsonSerializable()
class MusicEntity {

	MusicEntity();

	factory MusicEntity.fromJson(Map<String, dynamic> json) => $MusicEntityFromJson(json);

	Map<String, dynamic> toJson() => $MusicEntityToJson(this);

  int? code;
  String? msg;
  MusicData? data;
}

@JsonSerializable()
class MusicData {

	MusicData();

	factory MusicData.fromJson(Map<String, dynamic> json) => $MusicDataFromJson(json);

	Map<String, dynamic> toJson() => $MusicDataToJson(this);

  List<MusicDataContent>? content;
  MusicDataPageable? pageable;
  bool? last;
  int? totalPages;
  int? totalElements;
  MusicDataSort? sort;
  bool? first;
  int? number;
  int? numberOfElements;
  int? size;
  bool? empty;
}

@JsonSerializable()
class MusicDataContent {

	MusicDataContent();

	factory MusicDataContent.fromJson(Map<String, dynamic> json) => $MusicDataContentFromJson(json);

	Map<String, dynamic> toJson() => $MusicDataContentToJson(this);

  String? musicId;
  String? name;
  String? singer;
  String? lyricId;
  int? type;
  String? musicUri;
  String? lyricUri;
  String? coverUri;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MusicDataContent &&
          runtimeType == other.runtimeType &&
          musicId == other.musicId &&
          name == other.name &&
          singer == other.singer &&
          lyricId == other.lyricId &&
          type == other.type&&
          musicUri == other.musicUri&&
          lyricUri == other.lyricUri&&
          coverUri == other.coverUri;

  @override
  int get hashCode =>
      musicId.hashCode ^
      name.hashCode ^
      singer.hashCode ^
      lyricId.hashCode ^
      type.hashCode^
      musicUri.hashCode^
      lyricUri.hashCode^
      coverUri.hashCode;
}

@JsonSerializable()
class MusicDataPageable {

	MusicDataPageable();

	factory MusicDataPageable.fromJson(Map<String, dynamic> json) => $MusicDataPageableFromJson(json);

	Map<String, dynamic> toJson() => $MusicDataPageableToJson(this);

  MusicDataPageableSort? sort;
  int? pageNumber;
  int? pageSize;
  int? offset;
  bool? paged;
  bool? unpaged;
}

@JsonSerializable()
class MusicDataPageableSort {

	MusicDataPageableSort();

	factory MusicDataPageableSort.fromJson(Map<String, dynamic> json) => $MusicDataPageableSortFromJson(json);

	Map<String, dynamic> toJson() => $MusicDataPageableSortToJson(this);

  bool? unsorted;
  bool? sorted;
  bool? empty;
}

@JsonSerializable()
class MusicDataSort {

	MusicDataSort();

	factory MusicDataSort.fromJson(Map<String, dynamic> json) => $MusicDataSortFromJson(json);

	Map<String, dynamic> toJson() => $MusicDataSortToJson(this);

  bool? unsorted;
  bool? sorted;
  bool? empty;
}
