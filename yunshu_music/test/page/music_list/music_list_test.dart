import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunshu_music/page/music_list/component/music_list.dart';

void main() {
  test('music list accepts macOS trackpad scrolling', () {
    expect(musicListDragDevices, contains(PointerDeviceKind.trackpad));
  });
}
