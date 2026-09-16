import 'package:flutter_test/flutter_test.dart';
import 'package:yunshu_music/component/lyric/lyric.dart';
import 'package:yunshu_music/component/lyric/lyric_util.dart';

void main() {
  group('formatLyric', () {
    test('解析 [mm:ss] 无毫秒格式', () {
      final lyrics = LyricUtil.formatLyric('[00:30]你好\n');

      expect(lyrics, isNotNull);
      expect(lyrics!.length, 1);
      expect(lyrics.first.lyric, '你好');
      expect(lyrics.first.startTime, const Duration(seconds: 30));
    });

    test('解析 [mm:ss.SSS] 标准格式', () {
      final lyrics = LyricUtil.formatLyric('[01:02.345]标准\n');

      expect(lyrics, isNotNull);
      expect(lyrics!.length, 1);
      expect(
        lyrics.first.startTime,
        const Duration(minutes: 1, seconds: 2, milliseconds: 345),
      );
    });

    test('解析 [mm:ss:SSS] 冒号毫秒格式', () {
      final lyrics = LyricUtil.formatLyric('[01:02:345]冒号\n');

      expect(lyrics, isNotNull);
      expect(lyrics!.length, 1);
      expect(
        lyrics.first.startTime,
        const Duration(minutes: 1, seconds: 2, milliseconds: 345),
      );
    });

    test('一行多时间戳应生成多条歌词', () {
      final lyrics = LyricUtil.formatLyric('[00:10.00][01:20.00]副歌\n');

      expect(lyrics, isNotNull);
      expect(lyrics!.length, 2);
      expect(lyrics[0].lyric, '副歌');
      expect(lyrics[0].startTime, const Duration(seconds: 10));
      expect(lyrics[1].lyric, '副歌');
      expect(lyrics[1].startTime, const Duration(minutes: 1, seconds: 20));
    });

    test('忽略元信息标签并保留 offset 作用', () {
      final lyrics = LyricUtil.formatLyric(
        '[ti:标题]\n[offset:500]\n[00:10.00]第一句\n',
      );

      expect(lyrics, isNotNull);
      expect(lyrics!.length, 1);
      expect(lyrics.first.lyric, '第一句');
      expect(lyrics.first.startTime, const Duration(milliseconds: 9500));
    });
  });

  group('findIndexByDuration', () {
    List<Lyric> threeLines() =>
        LyricUtil.formatLyric('[00:00.00]a\n[00:10.00]b\n[00:20.00]c\n')!;

    test('命中对应区间', () {
      final lyrics = threeLines();

      expect(LyricUtil.findIndexByDuration(Duration.zero, lyrics), 0);
      expect(
        LyricUtil.findIndexByDuration(const Duration(seconds: 5), lyrics),
        0,
      );
      expect(
        LyricUtil.findIndexByDuration(const Duration(seconds: 15), lyrics),
        1,
      );
      expect(
        LyricUtil.findIndexByDuration(const Duration(seconds: 25), lyrics),
        2,
      );
    });

    test('第一条歌词开始之前返回 0', () {
      final lyrics = LyricUtil.formatLyric('[00:10.00]a\n[00:20.00]b\n')!;

      expect(
        LyricUtil.findIndexByDuration(const Duration(seconds: 3), lyrics),
        0,
      );
    });

    test('空列表返回 0', () {
      expect(LyricUtil.findIndexByDuration(Duration.zero, []), 0);
    });
  });
}
