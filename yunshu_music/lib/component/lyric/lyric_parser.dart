import 'package:yunshu_music/component/lyric/lyric.dart';

class LyricParser {
  static const Duration _lastLineEnd = Duration(hours: 200);

  /// 解析 LRC 文本；null/空白返回 null，无有效行返回空列表。
  static List<Lyric>? parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    if (!raw.endsWith("\n")) {
      raw += "\n";
    }
    raw = raw.replaceAll("\r", "");

    int offset = 0;
    final offsetMatch = RegExp(r'\[offset:(-?\d+)\]').firstMatch(raw);
    if (offsetMatch != null) {
      offset = int.tryParse(offsetMatch.group(1)!) ?? 0;
    }

    final RegExp timeTagReg = RegExp(r'\[(\d+):(\d+)(?:[.:](\d+))?\]');
    final List<_ParsedLine> parsed = [];
    for (final String line in raw.split("\n")) {
      if (line.trim().isEmpty) {
        continue;
      }
      final Iterable<RegExpMatch> matches = timeTagReg.allMatches(line);
      if (matches.isEmpty) {
        continue;
      }
      final String text = line.substring(matches.last.end);
      if (text.trim().isEmpty) {
        continue;
      }
      for (final RegExpMatch match in matches) {
        final String minute = match.group(1)!;
        final String second = match.group(2)!;
        final String? milli = match.group(3);
        final String time = milli == null
            ? "$minute:$second"
            : "$minute:$second.$milli";
        parsed.add(_ParsedLine(_timeToDuration(time, offset), text));
      }
    }
    if (parsed.isEmpty) {
      return const [];
    }
    parsed.sort((a, b) => a.start.compareTo(b.start));
    final List<Lyric> lyrics = [];
    for (int i = 0; i < parsed.length; i++) {
      final Duration end = i < parsed.length - 1
          ? parsed[i + 1].start
          : _lastLineEnd;
      lyrics.add(
        Lyric(text: parsed[i].text, startTime: parsed[i].start, endTime: end),
      );
    }
    return lyrics;
  }

  /// 按时间取歌词下标；二分查找，空列表返回 0。
  static int indexAt(Duration position, List<Lyric> lyrics) {
    if (lyrics.isEmpty) {
      return 0;
    }
    int low = 0;
    int high = lyrics.length - 1;
    while (low < high) {
      int mid = low + ((high - low) >> 1);
      if (position <= lyrics[mid].endTime) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    return low;
  }

  /// 支持 [分钟:秒]、[分钟:秒.毫秒]、[分钟:秒:毫秒]；offset 单位毫秒，正值整体提前。
  static Duration _timeToDuration(String time, int offset) {
    final int minuteSeparatorIndex = time.indexOf(":");
    int secondSeparatorIndex = time.indexOf(".");
    if (secondSeparatorIndex == -1) {
      final int lastColonIndex = time.lastIndexOf(":");
      secondSeparatorIndex = lastColonIndex == minuteSeparatorIndex
          ? -1
          : lastColonIndex;
    }

    final String minute = time.substring(0, minuteSeparatorIndex);
    final String seconds = secondSeparatorIndex == -1
        ? time.substring(minuteSeparatorIndex + 1)
        : time.substring(minuteSeparatorIndex + 1, secondSeparatorIndex);
    String milliseconds = secondSeparatorIndex == -1
        ? '0'
        : time.substring(secondSeparatorIndex + 1);
    if (milliseconds.isEmpty) {
      milliseconds = '0';
    }
    String microseconds = '0';
    if (milliseconds.length > 3) {
      microseconds = milliseconds.substring(3);
      milliseconds = milliseconds.substring(0, 3);
    }
    final Duration result = Duration(
      minutes: int.parse(minute),
      seconds: int.parse(seconds),
      milliseconds: int.parse(milliseconds) - offset,
      microseconds: int.parse(microseconds),
    );
    return result.compareTo(Duration.zero) < 0 ? Duration.zero : result;
  }
}

class _ParsedLine {
  final Duration start;
  final String text;

  _ParsedLine(this.start, this.text);
}
