import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/show_overlay_dialog.dart';
import 'package:simutil/components/simutil_theme.dart';
import 'package:simutil/models/device.dart';
import 'package:simutil/plugins/logcat/logcat_filter_bar.dart';
import 'package:simutil/plugins/logcat/logcat_helper.dart';

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
  /// Maximum number of lines to keep in memory.
  /// Avoid performance issues when the list of lines is too large.
  static const _maxLines = 500;
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

  Future<void> _startLogcat() async {
    try {
      final process = await Process.start(component.adbPath, [
        '-s',
        component.device.id,
        'logcat',
      ]);
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
      if (_lines.length > _maxLines) {
        _lines.removeAt(0);
      }
      _rebuildFiltered();

      if (_autoScroll) {
        _scrollIndex = _filteredLines.isEmpty ? 0 : _filteredLines.length - 1;
      } else {
        if (_scrollIndex > 0) _scrollIndex--;

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
            : _lines.where((l) => LogcatHelper.lineMatchesFilter(l, _filter)),
      );
  }

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
      setState(() {
        _filter = '';
        _filterController.text = '';
        _rebuildFiltered();
        if (_autoScroll && _filteredLines.isNotEmpty) {
          _scrollIndex = _filteredLines.length - 1;
        }
        _filterMode = false;
        _scrollController.ensureIndexVisible(index: _scrollIndex);
      });

      return true;
    }
    return false;
  }

  void _openPath(String path) {
    final opener = switch (Platform.operatingSystem) {
      'darwin' => 'open',
      'linux' => 'xdg-open',
      'windows' => 'start',
      _ => 'open',
    };
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
    final path = LogcatHelper.firstPath(_filteredLines[_scrollIndex]);
    if (path == null) return;
    _openPath(path);
  }

  bool _handleKeyEvent(KeyboardEvent event) {
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
          _scrollIndex = (_scrollIndex - 1).clamp(0, _filteredLines.length - 1);
        });
        _scrollController.ensureIndexVisible(index: _scrollIndex);
        return true;

      case LogicalKey.arrowDown:
        if (_filteredLines.isEmpty) return true;
        setState(() {
          _scrollIndex = (_scrollIndex + 1).clamp(0, _filteredLines.length - 1);
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

  TextStyle _lineStyle(String line, SimutilTheme st) =>
      switch (LogcatHelper.parseLevel(line)) {
        LogcatLevel.error || LogcatLevel.fatal => st.errorStyle,
        LogcatLevel.warning => st.warningStyle,
        LogcatLevel.debug => st.dimmed,
        LogcatLevel.verbose => st.muted,
        _ => st.body,
      };

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;
    return Center(
      child: Container(
        color: st.background,
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                  LogcatFilterBar(
                    controller: _filterController,
                    onChanged: _onFilterChanged,
                    onKeyEvent: _handleFilterKey,
                  ),
                ] else ...[
                  Divider(),
                  _buildHints(st),
                ],
              ],
            ),
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

  Component _buildLogLine(String line, int index, SimutilTheme st) {
    final isSelected = index == _scrollIndex;
    final match = LogcatHelper.pathRe.firstMatch(line);

    if (match == null) {
      return Text(line, style: isSelected ? st.selected : _lineStyle(line, st));
    }

    final path = match.group(1)!;
    final before = line.substring(0, match.start);
    final after = line.substring(match.end);

    final baseStyle = isSelected ? st.selected : _lineStyle(line, st);
    final linkStyle = isSelected
        ? st.selected.copyWith(decoration: TextDecoration.underline)
        : TextStyle(color: st.primary, decoration: TextDecoration.underline);

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

  Component _buildHints(SimutilTheme st) => Text(
    ' Navigate: <↑/↓> | Auto-scroll: a [${_autoScroll ? "ON" : "OFF"}]'
    ' | Filter: / | Open path: o | Clear: c | Close: <esc>',
    style: st.dimmed,
  );
}

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
