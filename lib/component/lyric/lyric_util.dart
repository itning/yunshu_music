/*
Copyright [2018] [Caijinglong]

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

修改说明：
1. 适配dart空安全
2. 注释修改
*/
import 'package:fluttertoast/fluttertoast.dart';
import 'package:yunshu_music/component/lyric/lyric.dart';

class LyricUtil {
  static var tags = ['ti', 'ar', 'al', 'offset', 'by'];

  /// 格式化歌词
  static List<Lyric>? formatLyric(String? lyricStr) {
    if (lyricStr == null || lyricStr.trim().isEmpty) {
      return null;
    }
    lyricStr = lyricStr.replaceAll("\r", "");
    RegExp reg = RegExp(r"""\[(.*?):(.*?)\](.*?)\n""");

    Iterable<Match>? matches;
    try {
      matches = reg.allMatches(lyricStr);
    } catch (e) {
      Fluttertoast.showToast(msg: "歌词解析失败", toastLength: Toast.LENGTH_LONG);
      print(e.toString());
    }

    List<Lyric> lyrics = [];
    List? list = matches?.toList();
    if (list != null) {
      for (int i = 0; i < list.length; i++) {
        var temp = list[i];
        var title = temp[1];
        if (!tags.contains(title)) {
          try {
            int.parse(title);
          } on FormatException catch (_, __) {
            continue;
          }
          lyrics.add(
            Lyric(
              list[i][3],
              startTime: lyricTimeToDuration(
                "${temp[1]}:${temp[2]}",
              ),
            ),
          );
        }
      }
    }
    //移除所有空歌词
    lyrics.removeWhere((lyric) => lyric.lyric.trim().isEmpty);
    for (int i = 0; i < lyrics.length - 1; i++) {
      lyrics[i].endTime = lyrics[i + 1].startTime;
    }
    if (lyrics.isEmpty) {
      return lyrics;
    }
    lyrics.last.endTime = const Duration(hours: 200);
    return lyrics;
  }

  static Duration lyricTimeToDuration(String time) {
    int minuteSeparatorIndex = time.indexOf(":");
    int secondSeparatorIndex = time.indexOf(".");

    // 分
    var minute = time.substring(0, minuteSeparatorIndex);
    // 秒
    var seconds =
        time.substring(minuteSeparatorIndex + 1, secondSeparatorIndex);
    // 微秒
    var millsceconds = time.substring(secondSeparatorIndex + 1);
    var microseconds = '0';
    // 判断是否存在微秒
    if (millsceconds.length > 3) {
      // 存在微秒 重新给予赋值
      microseconds = millsceconds.substring(3);
      millsceconds = millsceconds.substring(0, 3);
    }

    return Duration(
        minutes: int.parse(minute),
        seconds: int.parse(seconds),
        milliseconds: int.parse(millsceconds),
        microseconds: int.parse(microseconds));
  }
}
