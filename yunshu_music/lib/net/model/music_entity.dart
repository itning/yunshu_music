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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MusicDataContent &&
          runtimeType == other.runtimeType &&
          musicId == other.musicId &&
          name == other.name &&
          singer == other.singer &&
          lyricId == other.lyricId &&
          type == other.type;

  @override
  int get hashCode =>
      musicId.hashCode ^
      name.hashCode ^
      singer.hashCode ^
      lyricId.hashCode ^
      type.hashCode;
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
