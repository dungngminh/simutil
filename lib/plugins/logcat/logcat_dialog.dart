import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/show_overlay_dialog.dart';
import 'package:simutil/components/simutil_theme.dart';
import 'package:simutil/models/device.dart';

// ── log-level helpers ─────────────────────────────────────────────────────────

// Android logcat threadtime format: MM-DD HH:MM:SS.mmm  PID  TID  L tag  :
final _logLevelRe =
    RegExp(r'^\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+\s+\d+\s+\d+\s+([VDIWEF])\s');

enum _LogLevel { verbose, debug, info, warning, error, fatal, unknown }

_LogLevel _parseLevel(String line) {
  final m = _logLevelRe.firstMatch(line);
  if (m == null) return _LogLevel.unknown;
  return switch (m.group(1)) {
    'V' => _LogLevel.verbose,
    'D' => _LogLevel.debug,
    'I' => _LogLevel.info,
    'W' => _LogLevel.warning,
    'E' => _LogLevel.error,
    'F' => _LogLevel.fatal,
    _ => _LogLevel.unknown,
  };
}

bool _lineMatchesFilter(String line, String filter) {
  if (filter.isEmpty) return true;
  final f = filter.trim().toLowerCase();
  return switch (f) {
    'is:error' =>
      _parseLevel(line) == _LogLevel.error ||
          _parseLevel(line) == _LogLevel.fatal,
    'is:warn' => _parseLevel(line) == _LogLevel.warning,
    'is:info' => _parseLevel(line) == _LogLevel.info,
    'is:debug' => _parseLevel(line) == _LogLevel.debug,
    'is:verbose' => _parseLevel(line) == _LogLevel.verbose,
    _ => line.toLowerCase().contains(f),
  };
}

// Detect the first absolute path in a log line.
// The pattern matches an absolute path (starts with /) made up of characters
// valid in Unix paths; trailing punctuation common in prose is excluded to
// avoid accidentally capturing it as part of the path.
final _pathRe = RegExp(r'(/[^\s\x00-\x1f\)\]\x22\x27,:;]+)');

String? _firstPath(String line) => _pathRe.firstMatch(line)?.group(1);

// ── dialog ────────────────────────────────────────────────────────────────────

class LogcatDialog extends StatefulComponent {
  const LogcatDialog({
    super.key,
    required this.device,
    required this.adbPath,
    required this.onClose,
  });

  final Device device;
  final String adbPath;
  final VoidCallback onClose;

  @override
  State<LogcatDialog> createState() => _LogcatDialogState();
}

class _LogcatDialogState extends State<LogcatDialog> {
  static const int _maxLines = 500;

  final List<String> _lines = [];
  final List<String> _filteredLines = [];

  final ScrollController _scrollController = ScrollController();
  Process? _process;
  StreamSubscription<String>? _subscription;

  bool _autoScroll = true;
  int _scrollIndex = 0;

  bool _filterMode = false;
  String _filter = '';
  late final TextEditingController _filterController;

  @override
  void initState() {
    super.initState();
    _filterController = TextEditingController();
    _startLogcat();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _process?.kill();
    _scrollController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  // ── logcat process ──────────────────────────────────────────────────────────

  Future<void> _startLogcat() async {
    try {
      final process = await Process.start(
        component.adbPath,
        ['-s', component.device.id, 'logcat'],
      );
      _process = process;
      _subscription = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_onNewLine);
    } catch (e) {
      setState(() {
        _lines.add('Error starting logcat: $e');
        _rebuildFiltered();
      });
    }
  }

  void _onNewLine(String line) {
    setState(() {
      _lines.add(line);

      // When the buffer is full, remove the oldest entry and track whether it
      // was visible in the filtered view so _scrollIndex can be compensated.
      var removedVisible = false;
      if (_lines.length > _maxLines) {
        final removed = _lines.removeAt(0);
        removedVisible = _lineMatchesFilter(removed, _filter);
      }

      _rebuildFiltered();

      if (_autoScroll) {
        _scrollIndex = _filteredLines.isEmpty ? 0 : _filteredLines.length - 1;
      } else {
        if (removedVisible && _scrollIndex > 0) _scrollIndex--;
        _scrollIndex = _scrollIndex.clamp(
          0,
          _filteredLines.isEmpty ? 0 : _filteredLines.length - 1,
        );
      }
    });

    if (_filteredLines.isNotEmpty) {
      _scrollController.ensureIndexVisible(
        // When auto-scroll is on, jump to the tail; otherwise anchor the
        // viewport so incoming lines do not cause the view to drift.
        index: _autoScroll ? _filteredLines.length - 1 : _scrollIndex,
      );
    }
  }

  void _rebuildFiltered() {
    _filteredLines
      ..clear()
      ..addAll(
        _filter.isEmpty
            ? _lines
            : _lines.where((l) => _lineMatchesFilter(l, _filter)),
      );
  }

  // ── filter ──────────────────────────────────────────────────────────────────

  void _onFilterChanged(String value) {
    setState(() {
      _filter = value;
      _rebuildFiltered();
      _scrollIndex = _autoScroll || _filteredLines.isEmpty
          ? (_filteredLines.isEmpty ? 0 : _filteredLines.length - 1)
          : _scrollIndex.clamp(0, _filteredLines.length - 1);
    });
    if (_filteredLines.isNotEmpty) {
      _scrollController.ensureIndexVisible(
        index: _autoScroll ? _filteredLines.length - 1 : _scrollIndex,
      );
    }
  }

  bool _handleFilterKey(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.escape) {
      setState(() => _filterMode = false);
      return true;
    }
    return false;
  }

  // ── path open ───────────────────────────────────────────────────────────────

  void _openPath(String path) {
    final opener = Platform.isMacOS ? 'open' : 'xdg-open';
    Process.run(opener, [path]).then((result) {
      if (result.exitCode != 0) {
        setState(() {
          _lines.add('[simutil] Could not open "$path": ${result.stderr}');
          _rebuildFiltered();
        });
      }
    });
  }

  void _handleOpenPath() {
    if (_filteredLines.isEmpty || _scrollIndex >= _filteredLines.length) return;
    final path = _firstPath(_filteredLines[_scrollIndex]);
    if (path == null) return;
    _openPath(path);
  }

  // ── styling ─────────────────────────────────────────────────────────────────

  TextStyle _lineStyle(String line, SimutilTheme st) =>
      switch (_parseLevel(line)) {
        _LogLevel.error || _LogLevel.fatal => st.errorStyle,
        _LogLevel.warning => st.warningStyle,
        _LogLevel.debug => st.dimmed,
        _LogLevel.verbose => st.muted,
        _ => st.body,
      };

  // ── build ───────────────────────────────────────────────────────────────────

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;
    return Container(
      color: st.background,
      margin: EdgeInsets.all(1),
      decoration: st.dialogPanel('Logcat: ${component.device.name}'),
      child: Padding(
        padding: EdgeInsets.all(1),
        child: Focusable(
          focused: true,
          onKeyEvent: _handleKeyEvent,
          child: Column(
            children: [
              Expanded(child: _buildLogList(st)),
              if (_filterMode) ...[
                Divider(),
                _buildFilterBar(st),
                Text(
                  ' Quick: is:error · is:warn · is:info · is:debug · is:verbose'
                  '   <esc> close filter',
                  style: st.dimmed,
                ),
              ],
              Divider(),
              _buildHints(st),
            ],
          ),
        ),
      ),
    );
  }

  Component _buildLogList(SimutilTheme st) {
    if (_filteredLines.isEmpty) {
      return Center(
        child: Text(
          _filter.isNotEmpty ? 'No matching logs' : 'Waiting for logs…',
          style: st.dimmed,
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      itemCount: _filteredLines.length,
      itemBuilder: (context, index) =>
          _buildLogLine(_filteredLines[index], index, st),
    );
  }

  /// Builds a single log line.  Lines that contain an absolute path are
  /// rendered as rich text with the path underlined and styled as a link; the
  /// entire line row is wrapped in a [GestureDetector] so that a click opens
  /// the path (equivalent to Cmd+Click in GUI editors).
  Component _buildLogLine(String line, int index, SimutilTheme st) {
    final isSelected = index == _scrollIndex;
    final match = _pathRe.firstMatch(line);

    if (match == null) {
      return Text(line, style: isSelected ? st.selected : _lineStyle(line, st));
    }

    final path = match.group(1)!;
    final before = line.substring(0, match.start);
    final after = line.substring(match.end);

    final baseStyle = isSelected ? st.selected : _lineStyle(line, st);
    final linkStyle = isSelected
        ? st.selected.copyWith(decoration: TextDecoration.underline)
        : TextStyle(
            color: st.primary,
            decoration: TextDecoration.underline,
          );

    return GestureDetector(
      onTap: () => _openPath(path),
      child: RichText(
        text: TextSpan(
          style: baseStyle,
          children: [
            if (before.isNotEmpty) TextSpan(text: before),
            TextSpan(text: path, style: linkStyle),
            if (after.isNotEmpty) TextSpan(text: after),
          ],
        ),
      ),
    );
  }

  Component _buildFilterBar(SimutilTheme st) {
    final countLabel =
        _filter.isEmpty ? '' : ' [${_filteredLines.length}/${_lines.length}]';
    return Row(
      children: [
        Text(' Filter$countLabel: ', style: st.label),
        Expanded(
          child: TextField(
            controller: _filterController,
            focused: true,
            onChanged: _onFilterChanged,
            onKeyEvent: _handleFilterKey,
            style: st.body,
            decoration: InputDecoration(
              border: BoxBorder.all(
                style: BoxBorderStyle.rounded,
                color: st.outline,
              ),
              focusedBorder: BoxBorder.all(
                style: BoxBorderStyle.rounded,
                color: st.primary,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 1),
            ),
          ),
        ),
      ],
    );
  }

  Component _buildHints(SimutilTheme st) => Text(
    ' <↑/↓> scroll | a auto-scroll [${_autoScroll ? "ON" : "OFF"}]'
    ' | / filter | click path to open | o open selected path | c clear | <esc> close',
    style: st.dimmed,
  );

  // ── key handling ────────────────────────────────────────────────────────────

  bool _handleKeyEvent(KeyboardEvent event) {
    // When filter mode is active the inner TextField (deeper in the tree) gets
    // key events first.  We only need to handle anything that slips through.
    if (_filterMode) return false;

    switch (event.logicalKey) {
      case LogicalKey.escape:
        if (_filter.isNotEmpty) {
          setState(() {
            _filter = '';
            _filterController.text = '';
            _rebuildFiltered();
            if (_autoScroll && _filteredLines.isNotEmpty) {
              _scrollIndex = _filteredLines.length - 1;
            }
          });
        } else {
          component.onClose();
        }
        return true;

      case LogicalKey.arrowUp:
        if (_filteredLines.isEmpty) return true;
        setState(() {
          _autoScroll = false;
          _scrollIndex =
              (_scrollIndex - 1).clamp(0, _filteredLines.length - 1);
        });
        _scrollController.ensureIndexVisible(index: _scrollIndex);
        return true;

      case LogicalKey.arrowDown:
        if (_filteredLines.isEmpty) return true;
        setState(() {
          _scrollIndex =
              (_scrollIndex + 1).clamp(0, _filteredLines.length - 1);
          _autoScroll = _scrollIndex >= _filteredLines.length - 1;
        });
        _scrollController.ensureIndexVisible(index: _scrollIndex);
        return true;

      case LogicalKey.keyA:
        setState(() => _autoScroll = !_autoScroll);
        if (_autoScroll && _filteredLines.isNotEmpty) {
          _scrollIndex = _filteredLines.length - 1;
          _scrollController.ensureIndexVisible(index: _scrollIndex);
        }
        return true;

      case LogicalKey.keyC:
        setState(() {
          _lines.clear();
          _filteredLines.clear();
          _scrollIndex = 0;
        });
        return true;

      case LogicalKey.slash:
        setState(() => _filterMode = true);
        return true;

      case LogicalKey.keyO:
        _handleOpenPath();
        return true;

      default:
        return false;
    }
  }
}

// ── show helper ───────────────────────────────────────────────────────────────

Future<void> showLogcatDialog({
  required BuildContext context,
  required Device device,
  required String adbPath,
}) => showOverlayDialog<void>(
  context: context,
  builder: (context, completer, entry) => LogcatDialog(
    device: device,
    adbPath: adbPath,
    onClose: () {
      completer.complete();
      entry?.remove();
    },
  ),
);
