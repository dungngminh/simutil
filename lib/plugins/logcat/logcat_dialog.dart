import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/show_overlay_dialog.dart';
import 'package:simutil/components/simutil_theme.dart';
import 'package:simutil/models/device.dart';

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
  final ScrollController _scrollController = ScrollController();
  Process? _process;
  StreamSubscription<String>? _subscription;
  bool _autoScroll = true;
  int _scrollIndex = 0;

  @override
  void initState() {
    super.initState();
    _startLogcat();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _process?.kill();
    _scrollController.dispose();
    super.dispose();
  }

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
      });
    }
  }

  void _onNewLine(String line) {
    setState(() {
      _lines.add(line);
      if (_lines.length > _maxLines) {
        _lines.removeAt(0);
        // Compensate for the removed front item so the same content stays visible.
        if (!_autoScroll && _scrollIndex > 0) {
          _scrollIndex--;
        }
      }
      if (_autoScroll) {
        _scrollIndex = _lines.length - 1;
      }
    });
    if (_autoScroll) {
      _scrollController.ensureIndexVisible(index: _lines.length - 1);
    } else {
      // Anchor the viewport to the current position so new lines
      // appended at the bottom do not cause the view to drift.
      _scrollController.ensureIndexVisible(index: _scrollIndex);
    }
  }

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
              Expanded(
                child: _lines.isEmpty
                    ? Center(
                        child: Text('Waiting for logs…', style: st.dimmed),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _lines.length,
                        itemBuilder: (context, index) {
                          return Text(_lines[index], style: st.body);
                        },
                      ),
              ),
              Divider(),
              Text(
                ' Scroll: <↑/↓> | Auto-scroll: a [${_autoScroll ? "ON" : "OFF"}] | Clear: c | Close: <esc>',
                style: st.dimmed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    switch (event.logicalKey) {
      case LogicalKey.escape:
        component.onClose();
        return true;
      case LogicalKey.arrowUp:
        setState(() {
          _autoScroll = false;
          _scrollIndex = (_scrollIndex - 1).clamp(0, _lines.length - 1);
        });
        _scrollController.ensureIndexVisible(index: _scrollIndex);
        return true;
      case LogicalKey.arrowDown:
        setState(() {
          _scrollIndex = (_scrollIndex + 1).clamp(0, _lines.length - 1);
          _autoScroll = _scrollIndex >= _lines.length - 1;
        });
        _scrollController.ensureIndexVisible(index: _scrollIndex);
        return true;
      case LogicalKey.keyA:
        setState(() => _autoScroll = !_autoScroll);
        if (_autoScroll && _lines.isNotEmpty) {
          _scrollIndex = _lines.length - 1;
          _scrollController.ensureIndexVisible(index: _scrollIndex);
        }
        return true;
      case LogicalKey.keyC:
        setState(() {
          _lines.clear();
          _scrollIndex = 0;
        });
        return true;
      default:
        return false;
    }
  }
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
