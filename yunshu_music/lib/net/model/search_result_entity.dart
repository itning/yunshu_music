import 'package:yunshu_music/generated/json/base/json_field.dart';
import 'package:yunshu_music/generated/json/search_result_entity.g.dart';
import 'dart:convert';
// use FlutterJsonBeanFactory plugin in idea to generate
@JsonSerializable()
class SearchResultEntity {

	int? code;
	String? msg;
	List<SearchResultData>? data;
  
  SearchResultEntity();

  factory SearchResultEntity.fromJson(Map<String, dynamic> json) => $SearchResultEntityFromJson(json);

  Map<String, dynamic> toJson() => $SearchResultEntityToJson(this);

  @override
  String toString() {
    return jsonEncode(this);
  }
}

@JsonSerializable()
class SearchResultData {

	String? musicId;
	String? name;
	String? singer;
	String? lyricId;
	int? type;
	String? musicUri;
	String? lyricUri;
	String? coverUri;
	List<String>? highlightFields;
  
  SearchResultData();

  factory SearchResultData.fromJson(Map<String, dynamic> json) => $SearchResultDataFromJson(json);

  Map<String, dynamic> toJson() => $SearchResultDataToJson(this);

  @override
  String toString() {
    return jsonEncode(this);
  }
}