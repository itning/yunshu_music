import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yunshu_music/net/http_helper.dart';
import 'package:yunshu_music/net/model/music_entity.dart';
import 'package:yunshu_music/net/model/search_result_entity.dart';
import 'package:yunshu_music/provider/music_data_model.dart';

class SearchModel extends ChangeNotifier {
  static SearchModel? _instance;

  static SearchModel get() {
    _instance ??= SearchModel();
    return _instance!;
  }

  List<SearchResultItem> _searchResults = [];

  List<SearchResultItem> get searchResults => _searchResults;

  Timer? _debounce;

  void search(String keyword) async {
    if (keyword.trim() == '') {
      _searchResults = [];
      return;
    }
    if (_debounce?.isActive ?? false) {
      _debounce?.cancel();
    }
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      await _innerSearch(keyword);
    });
  }

  Future<void> _innerSearch(String keyword) async {
    List<MusicData> result = MusicDataModel.get().search(keyword);
    SearchResultEntity? searchResultEntity =
        await HttpHelper.get().search(keyword);
    // 合并
    List<SearchResultData> data = searchResultEntity?.data ?? [];
    List<SearchResultItem> list = [
      ...(result
          .map((item) => SearchResultItem.fromMusicDataContent(item))
          .toList()),
      ...(data
          .map((item) => SearchResultItem.fromSearchResultData(item))
          .toList())
    ];
    _searchResults = list;
    notifyListeners();
  }
}

class SearchResultItem {
  bool fromLyric = false;
  String? musicId;
  String? name;
  String? singer;
  String? lyricId;
  int? type;
  String? musicUri;
  String? lyricUri;
  String? coverUri;
  List<String>? highlightFields;

  SearchResultItem(
      this.fromLyric,
      this.musicId,
      this.name,
      this.singer,
      this.lyricId,
      this.type,
      this.musicUri,
      this.lyricUri,
      this.coverUri,
      this.highlightFields);

  static SearchResultItem fromMusicDataContent(MusicData musicDataContent) {
    return SearchResultItem(
        false,
        musicDataContent.musicId,
        musicDataContent.name,
        musicDataContent.singer,
        musicDataContent.lyricId,
        musicDataContent.type,
        musicDataContent.musicUri,
        musicDataContent.lyricUri,
        musicDataContent.coverUri,
        null);
  }

  static SearchResultItem fromSearchResultData(
      SearchResultData searchResultData) {
    return SearchResultItem(
        true,
        searchResultData.musicId,
        searchResultData.name,
        searchResultData.singer,
        searchResultData.lyricId,
        searchResultData.type,
        searchResultData.musicUri,
        searchResultData.lyricUri,
        searchResultData.coverUri,
        searchResultData.highlightFields);
  }
}
