class Lyric {
  final String text;
  final Duration startTime;
  final Duration endTime;

  const Lyric({
    required this.text,
    required this.startTime,
    required this.endTime,
  });

  @override
  String toString() =>
      'Lyric{text: $text, startTime: $startTime, endTime: $endTime}';
}
