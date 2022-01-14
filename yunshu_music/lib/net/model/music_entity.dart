import 'package:yunshu_music/generated/json/base/json_convert_content.dart';

class MusicEntity with JsonConvert<MusicEntity> {
  int? code;
  String? msg;
  MusicData? data;
}

class MusicData with JsonConvert<MusicData> {
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

class MusicDataContent with JsonConvert<MusicDataContent> {
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

class MusicDataPageable with JsonConvert<MusicDataPageable> {
  MusicDataPageableSort? sort;
  int? pageNumber;
  int? pageSize;
  int? offset;
  bool? paged;
  bool? unpaged;
}

class MusicDataPageableSort with JsonConvert<MusicDataPageableSort> {
  bool? unsorted;
  bool? sorted;
  bool? empty;
}

class MusicDataSort with JsonConvert<MusicDataSort> {
  bool? unsorted;
  bool? sorted;
  bool? empty;
}
