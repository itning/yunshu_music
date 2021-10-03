import 'package:flutter/material.dart';
import 'package:tuple/tuple.dart';

/// 路由带动画的
Route createRoute(Widget page) {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 125),
    reverseTransitionDuration: const Duration(milliseconds: 125),
    opaque: true,
    fullscreenDialog: false,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      );
    },
  );
}

/// 根据[keyword]搜索[rawString]中存在的字符串索引，返回值item1指起始位置；item2指结束位置
List<Tuple2<int, int>> search(String rawString, String keyword) {
  Iterable<Match> matchIterable = keyword.allMatches(rawString);
  return List.generate(matchIterable.length, (index) {
    Match match = matchIterable.elementAt(index);
    return Tuple2(match.start, match.end);
  });
}

/// 高亮显示（红色）字符在字符串中的文字
List<TextSpan> highlight(
    String rawString, List<Tuple2<int, int>> highlightList) {
  List<TextSpan> result = [];
  int nextIndex = 0;
  for (int i = 0; i <= highlightList.length; i++) {
    if (i == highlightList.length) {
      String plain = rawString.substring(nextIndex);
      result.add(TextSpan(text: plain));
      break;
    }
    Tuple2<int, int> startEndIndex = highlightList[i];
    String start = rawString.substring(nextIndex, startEndIndex.item1);
    String h = rawString.substring(startEndIndex.item1, startEndIndex.item2);
    nextIndex = startEndIndex.item2;
    if (start != '') {
      result.add(TextSpan(text: start));
    }
    if (h != '') {
      result.add(TextSpan(text: h, style: const TextStyle(color: Colors.red)));
    }
  }
  return result;
}
