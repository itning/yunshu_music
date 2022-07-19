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
3. 歌词如果不是换行符结尾则添加换行符
*/
import 'package:fluttertoast/fluttertoast.dart';
import 'package:yunshu_music/component/lyric/lyric.dart';
import 'package:yunshu_music/util/common_utils.dart';

class LyricUtil {
  static var tags = ['ti', 'ar', 'al', 'offset', 'by'];

  /// 格式化歌词
  static List<Lyric>? formatLyric(String? lyricStr) {
    if (lyricStr == null || lyricStr.trim().isEmpty) {
      return null;
    }
    if (!lyricStr.endsWith("\n")) {
      lyricStr += "\n";
    }
    lyricStr = lyricStr.replaceAll("\r", "");
    RegExp reg = RegExp(r"""\[(.*?):(.*?)\](.*?)\n""");

    Iterable<Match>? matches;
    try {
      matches = reg.allMatches(lyricStr);
    } catch (e) {
      Fluttertoast.showToast(msg: "歌词解析失败", toastLength: Toast.LENGTH_LONG);
      LogHelper.get().error('歌词解析失败', e);
    }

    List<Lyric> lyrics = [];
    List? list = matches?.toList();
    if (list != null) {
      int offset = 0;
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
              temp[3],
              startTime: lyricTimeToDuration("$title:${temp[2]}", offset),
            ),
          );
        } else if (title == "offset" && offset == 0) {
          try {
            offset = int.parse(temp[2]);
          } on FormatException catch (e) {
            LogHelper.get().warn('parse offset [${temp[2]}] to int error', e);
          }
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

  /// 1、标准格式： [分钟:秒.毫秒] 歌词
  /// 2、其他格式①：[分钟:秒] 歌词；
  /// 3、其他格式②：[分钟:秒:毫秒] 歌词，与标准格式相比，秒后边的点号被改成了冒号。
  /// offset 其单位是毫秒，正值表示整体提前，负值相反。
  static Duration lyricTimeToDuration(String time, [int offset = 0]) {
    int minuteSeparatorIndex = time.indexOf(":");
    int secondSeparatorIndex = time.indexOf(".");
    if (secondSeparatorIndex == -1) {
      secondSeparatorIndex = time.lastIndexOf(":");
    }

    // 分
    var minute = time.substring(0, minuteSeparatorIndex);
    // 秒
    var seconds =
        time.substring(minuteSeparatorIndex + 1, secondSeparatorIndex);
    // 微秒
    var milliseconds = time.substring(secondSeparatorIndex + 1);
    var microseconds = '0';
    // 判断是否存在微秒
    if (milliseconds.length > 3) {
      // 存在微秒 重新给予赋值
      microseconds = milliseconds.substring(3);
      milliseconds = milliseconds.substring(0, 3);
    }
    Duration result = Duration(
        minutes: int.parse(minute),
        seconds: int.parse(seconds),
        milliseconds: int.parse(milliseconds) - offset,
        microseconds: int.parse(microseconds));
    return result.compareTo(Duration.zero) < 0 ? Duration.zero : result;
  }
}
