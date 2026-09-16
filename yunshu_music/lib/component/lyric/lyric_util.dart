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
import 'package:yunshu_music/component/lyric/lyric.dart';

class LyricUtil {
  /// 格式化歌词
  static List<Lyric>? formatLyric(String? lyricStr) {
    if (lyricStr == null || lyricStr.trim().isEmpty) {
      return null;
    }
    if (!lyricStr.endsWith("\n")) {
      lyricStr += "\n";
    }
    lyricStr = lyricStr.replaceAll("\r", "");

    // 全局 offset，单位毫秒，正值表示整体提前，负值相反
    int offset = 0;
    Match? offsetMatch = RegExp(r'\[offset:(-?\d+)\]').firstMatch(lyricStr);
    if (offsetMatch != null) {
      offset = int.tryParse(offsetMatch.group(1)!) ?? 0;
    }

    // 支持 [分钟:秒]、[分钟:秒.毫秒]、[分钟:秒:毫秒]，且一行可有多个时间戳
    RegExp timeTagReg = RegExp(r'\[(\d+):(\d+)(?:[.:](\d+))?\]');
    List<Lyric> lyrics = [];
    for (String line in lyricStr.split("\n")) {
      if (line.trim().isEmpty) {
        continue;
      }
      Iterable<RegExpMatch> matches = timeTagReg.allMatches(line);
      if (matches.isEmpty) {
        continue;
      }
      // 歌词正文为最后一个时间戳标签之后的内容
      String text = line.substring(matches.last.end);
      if (text.trim().isEmpty) {
        continue;
      }
      for (RegExpMatch match in matches) {
        String minute = match.group(1)!;
        String second = match.group(2)!;
        String? milli = match.group(3);
        String time = milli == null
            ? "$minute:$second"
            : "$minute:$second.$milli";
        lyrics.add(Lyric(text, startTime: lyricTimeToDuration(time, offset)));
      }
    }
    if (lyrics.isEmpty) {
      return lyrics;
    }
    // 一行多时间戳可能打乱顺序，统一按时间排序
    lyrics.sort((a, b) => a.startTime.compareTo(b.startTime));
    for (int i = 0; i < lyrics.length - 1; i++) {
      lyrics[i].endTime = lyrics[i + 1].startTime;
    }
    lyrics.last.endTime = const Duration(hours: 200);
    return lyrics;
  }

  /// 根据当前时长获取歌词下标。
  ///
  /// 歌词按 [Lyric.startTime] 有序，且前一条的 endTime 等于后一条的 startTime，
  /// 因此对 endTime 二分查找，返回第一个 endTime 不早于 [duration] 的下标。
  static int findIndexByDuration(Duration duration, List<Lyric> lyrics) {
    if (lyrics.isEmpty) {
      return 0;
    }
    int low = 0;
    int high = lyrics.length - 1;
    while (low < high) {
      int mid = low + ((high - low) >> 1);
      if (duration <= lyrics[mid].endTime!) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    return low;
  }

  /// 1、标准格式： [分钟:秒.毫秒] 歌词
  /// 2、其他格式①：[分钟:秒] 歌词；
  /// 3、其他格式②：[分钟:秒:毫秒] 歌词，与标准格式相比，秒后边的点号被改成了冒号。
  /// offset 其单位是毫秒，正值表示整体提前，负值相反。
  static Duration lyricTimeToDuration(String time, [int offset = 0]) {
    int minuteSeparatorIndex = time.indexOf(":");
    int secondSeparatorIndex = time.indexOf(".");
    if (secondSeparatorIndex == -1) {
      int lastColonIndex = time.lastIndexOf(":");
      // mm:ss:SSS 格式，用最后一个冒号分隔毫秒；mm:ss 格式则无毫秒
      secondSeparatorIndex = lastColonIndex == minuteSeparatorIndex
          ? -1
          : lastColonIndex;
    }

    // 分
    var minute = time.substring(0, minuteSeparatorIndex);
    // 秒
    var seconds = secondSeparatorIndex == -1
        ? time.substring(minuteSeparatorIndex + 1)
        : time.substring(minuteSeparatorIndex + 1, secondSeparatorIndex);
    // 微秒
    var milliseconds = secondSeparatorIndex == -1
        ? ''
        : time.substring(secondSeparatorIndex + 1);
    if (milliseconds.isEmpty) {
      milliseconds = '0';
    }
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
      microseconds: int.parse(microseconds),
    );
    return result.compareTo(Duration.zero) < 0 ? Duration.zero : result;
  }
}
