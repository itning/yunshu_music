import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

/// https://github.com/xaynetwork/logger_flutter
class _WrappedOutput implements LogOutput {
  final Function(OutputEvent e) outputListener;
  final LogOutput innerLogOutput;

  _WrappedOutput(this.outputListener, this.innerLogOutput);

  @override
  void output(OutputEvent event) {
    innerLogOutput.output(event);
    outputListener(event);
  }

  @override
  Future<void> destroy() async {
    innerLogOutput.destroy();
  }

  @override
  Future<void> init() async {
    innerLogOutput.init();
  }
}

class LogConsole extends StatefulWidget {
  final bool dark;
  final bool showCloseButton;

  static final ListQueue<OutputEvent> _outputEventBuffer = ListQueue();
  static bool _initialized = false;
  static final _newLogs = ChangeNotifier();

  LogConsole({super.key, this.dark = false, this.showCloseButton = false})
      : assert(_initialized, 'Please call LogConsole.init() first.');

  /// Attach this LogOutput to your logger instance:
  /// `
  /// Logger(
  ///     printer: PrettyPrinter(
  ///       printTime: true,
  ///       printEmojis: true,
  ///       colors: true,
  ///       methodCount: methodCount,
  ///       errorMethodCount: errMethodCount,
  ///     ),
  ///     level: level,
  ///     output: LogConsole.wrap(output),
  ///     filter: ProductionFiler(),
  ///   );
  /// `
  static LogOutput wrap({int bufferSize = 1000, LogOutput? innerOutput}) {
    _initialized = true;

    final output = innerOutput ?? ConsoleOutput();

    return _WrappedOutput((e) {
      if (_outputEventBuffer.length == bufferSize) {
        _outputEventBuffer.removeFirst();
      }
      _outputEventBuffer.add(e);
      // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
      _newLogs.notifyListeners();
    }, output);
  }

  @override
  State<LogConsole> createState() => _LogConsoleState();

  static void openLogConsole(BuildContext context) async {
    var logConsole = LogConsole(
      showCloseButton: true,
      dark: Theme.of(context).brightness == Brightness.dark,
    );
    PageRoute route;
    route = MaterialPageRoute(builder: (_) => logConsole);

    await Navigator.push(context, route);
  }
}

class RenderedEvent {
  final int id;
  final Level level;
  final String text;

  RenderedEvent(this.id, this.level, this.text);
}

class _LogConsoleState extends State<LogConsole> {
  final ListQueue<RenderedEvent> _renderedBuffer = ListQueue();
  List<RenderedEvent> _filteredBuffer = [];

  final _scrollController = ScrollController();
  final _filterController = TextEditingController();

  Level _filterLevel = Level.trace;
  double _logFontSize = 10;

  var _currentId = 0;
  bool _scrollListenerEnabled = true;
  bool _followBottom = true;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (!_scrollListenerEnabled) return;
      var scrolledToBottom = _scrollController.offset >=
          _scrollController.position.maxScrollExtent;
      setState(() {
        _followBottom = scrolledToBottom;
      });
    });

    LogConsole._newLogs.addListener(_onNewLogs);
  }

  void _onNewLogs() {
    setState(() {
      _reloadContent();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _reloadContent();
  }

  void _reloadContent() {
    _renderedBuffer.clear();
    for (var event in LogConsole._outputEventBuffer) {
      _renderedBuffer.add(_renderEvent(event));
    }
    _refreshFilter();
  }

  void _refreshFilter() {
    var newFilteredBuffer = _renderedBuffer.where((it) {
      var logLevelMatches = it.level.index >= _filterLevel.index;
      if (!logLevelMatches) {
        return false;
      } else if (_filterController.text.isNotEmpty) {
        var filterText = _filterController.text.toLowerCase();
        return it.text.toLowerCase().contains(filterText);
      } else {
        return true;
      }
    }).toList();
    setState(() {
      _filteredBuffer = newFilteredBuffer;
    });

    if (_followBottom) {
      Future.delayed(Duration.zero, _scrollToBottom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: widget.dark
          ? ThemeData(
              brightness: Brightness.dark,
              // accentColor: Colors.blueGrey,
            )
          : ThemeData(
              brightness: Brightness.light,
              // accentColor: Colors.lightBlueAccent,
            ),
      home: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildTopBar(),
              Expanded(
                child: _buildLogContent(),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
        floatingActionButton: AnimatedOpacity(
          opacity: _followBottom ? 0 : 1,
          duration: Duration(milliseconds: 150),
          child: Padding(
            padding: EdgeInsets.only(bottom: 60),
            child: FloatingActionButton(
              mini: true,
              clipBehavior: Clip.antiAlias,
              onPressed: _scrollToBottom,
              child: Icon(
                Icons.arrow_downward,
                color: widget.dark ? Colors.white : Colors.lightBlue[900],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogContent() {
    final text = StringBuffer();
    for (var e in _filteredBuffer) {
      text.write(e.text);
      text.write('\n');
    }

    return Container(
      color: widget.dark ? Colors.black : Colors.grey[150],
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        controller: _scrollController,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 1600,
            child: SelectableText(
              text.toString(),
              style: TextStyle(fontSize: _logFontSize),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return LogBar(
      dark: widget.dark,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Text(
            'Log Console',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Spacer(),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              setState(() {
                _logFontSize++;
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.remove),
            onPressed: () {
              setState(() {
                _logFontSize--;
              });
            },
          ),
          if (widget.showCloseButton)
            IconButton(
              icon: Icon(Icons.close),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return LogBar(
      dark: widget.dark,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Expanded(
            child: TextField(
              style: TextStyle(fontSize: 20),
              controller: _filterController,
              onChanged: (s) => _refreshFilter(),
              decoration: InputDecoration(
                labelText: 'Filter log output',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(width: 20),
          DropdownButton(
            value: _filterLevel,
            items: [
              DropdownMenuItem(
                value: Level.trace,
                child: Text('TRACE'),
              ),
              DropdownMenuItem(
                value: Level.debug,
                child: Text('DEBUG'),
              ),
              DropdownMenuItem(
                value: Level.info,
                child: Text('INFO'),
              ),
              DropdownMenuItem(
                value: Level.warning,
                child: Text('WARNING'),
              ),
              DropdownMenuItem(
                value: Level.error,
                child: Text('ERROR'),
              ),
              DropdownMenuItem(
                value: Level.fatal,
                child: Text('FATAL'),
              )
            ],
            onChanged: (value) {
              _filterLevel = value as Level;
              _refreshFilter();
            },
          )
        ],
      ),
    );
  }

  void _scrollToBottom() async {
    _scrollListenerEnabled = false;

    setState(() {
      _followBottom = true;
    });

    var scrollPosition = _scrollController.position;
    await _scrollController.animateTo(
      scrollPosition.maxScrollExtent,
      duration: Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );

    _scrollListenerEnabled = true;
  }

  RenderedEvent _renderEvent(OutputEvent event) {
    var text = event.lines.join('\n');
    return RenderedEvent(
      _currentId++,
      event.level,
      text,
    );
  }

  @override
  void dispose() {
    LogConsole._newLogs.removeListener(_onNewLogs);
    super.dispose();
  }
}

class LogBar extends StatelessWidget {
  final bool dark;
  final Widget child;

  const LogBar({super.key, this.dark = false, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            if (!dark)
              BoxShadow(
                color: Colors.grey[400]!,
                blurRadius: 3,
              ),
          ],
        ),
        child: Material(
          color: dark ? Colors.blueGrey[900] : Colors.white,
          child: Padding(
            padding: EdgeInsets.fromLTRB(15, 8, 15, 8),
            child: child,
          ),
        ),
      ),
    );
  }
}
