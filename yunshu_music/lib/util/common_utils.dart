import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:yunshu_music/method_channel/music_channel.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/util/log_console.dart';

class LogHelper {
  static final Logger _logger = Logger(
    output: LogConsole.wrap(
        innerOutput: (!kIsWeb && Platform.isWindows)
            ? MultiOutput(
                [ConsoleOutput(), FileOutput(file: File("./yunshu_music.log"))])
            : ConsoleOutput()),
    filter: ProductionFilter(),
    printer: SimplePrinter(printTime: true),
  );
  static LogHelper? _logHelper;

  static LogHelper get() {
    _logHelper ??= LogHelper();
    return _logHelper!;
  }

  void debug(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.log(Level.debug, message, error, stackTrace);
  }

  void info(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.log(Level.info, message, error, stackTrace);
  }

  void warn(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.log(Level.warning, message, error, stackTrace);
  }

  void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.log(Level.error, message, error, stackTrace);
  }
}

/// see https://github.com/leisim/logger/issues/128
class FileOutput extends LogOutput {
  final File file;
  final bool overrideExisting;
  final Encoding encoding;
  IOSink? _sink;

  FileOutput({
    required this.file,
    this.overrideExisting = false,
    this.encoding = utf8,
  });

  @override
  void init() {
    _sink = file.openWrite(
      mode: overrideExisting ? FileMode.writeOnly : FileMode.writeOnlyAppend,
      encoding: encoding,
    );
  }

  @override
  void output(OutputEvent event) {
    _sink?.writeAll(event.lines, '\n');
    _sink?.writeln();
  }

  @override
  void destroy() async {
    await _sink?.flush();
    await _sink?.close();
  }
}

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
  Iterable<Match> matchIterable =
      keyword.toLowerCase().allMatches(rawString.toLowerCase());
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

/// 显示播放列表
void showPlayList(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
    isScrollControlled: true, // set this to true
    builder: (_) {
      return FutureBuilder(
        future: MusicChannel.get().getPlayList(),
        builder: (BuildContext context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.data == null) {
              return DraggableScrollableSheet(
                maxChildSize: 0.5,
                expand: false,
                builder: (_, controller) {
                  return const Center(
                    child: Text('播放列表为空'),
                  );
                },
              );
            }
            return DraggableScrollableSheet(
              maxChildSize: 0.5,
              expand: false,
              builder: (_, controller) {
                return _PlayList(
                  scrollController: controller,
                  data: snapshot.data!,
                );
              },
            );
          }
          return DraggableScrollableSheet(
            maxChildSize: 0.5,
            expand: false,
            builder: (_, controller) {
              return const Center(
                child: Text('加载中...'),
              );
            },
          );
        },
      );
    },
  );
}

class _PlayList extends StatelessWidget {
  final ScrollController? scrollController;
  final List<dynamic> data;

  const _PlayList({Key? key, this.scrollController, required this.data})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<dynamic> reversed = data.reversed.toList();
    return ListView.builder(
        controller: scrollController,
        itemCount: reversed.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return Container(
              alignment: AlignmentDirectional.center,
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: const Text('播放列表'),
            );
          }
          index -= 1;
          return Dismissible(
            key: Key(reversed[index]['mediaId']),
            onDismissed: (DismissDirection direction) {
              MusicChannel.get()
                  .delPlayListByMediaId(reversed[index]['mediaId']);
            },
            child: InkWell(
              onTap: () {
                context
                    .read<MusicDataModel>()
                    .setNowPlayMusicUseMusicId(reversed[index]['mediaId']);
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8.0, top: 8.0),
                child: Flex(
                  direction: Axis.horizontal,
                  children: [
                    Expanded(
                        flex: 2,
                        child: Selector<MusicDataModel, String?>(
                          builder:
                              (BuildContext context, musicId, Widget? child) {
                            if (musicId != reversed[index]['mediaId']) {
                              return Text(
                                '${reversed.length - index}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey),
                              );
                            } else {
                              return const Icon(Icons.equalizer,
                                  color: Colors.black);
                            }
                          },
                          selector: (_, model) =>
                              model.getNowPlayMusic()?.musicId,
                        )),
                    Expanded(
                      flex: 13,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${reversed[index]['title']}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16.0),
                          ),
                          Text(
                            '${reversed[index]['subTitle']}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.0, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
  }
}

/// 修改标题
void setTitle(String title) {
  SystemChrome.setApplicationSwitcherDescription(
      ApplicationSwitcherDescription(label: title));
}
