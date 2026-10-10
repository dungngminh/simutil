import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:simutil_app/src/ui/design/design.dart';

/// `REC 00:01:23`: a pill showing how long a recording has run, refreshed
/// every second.
class RecordingClock extends StatefulWidget {
  const RecordingClock({super.key, required this.elapsed});

  /// Length of the recording so far; read on every tick.
  final Duration Function() elapsed;

  @override
  State<RecordingClock> createState() => _RecordingClockState();
}

class _RecordingClockState extends State<RecordingClock> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SimuStatusPill(
    label: 'REC ${formatRecordingTime(widget.elapsed())}',
    color: SimuTokens.of(context).danger,
  );
}

/// [d] as `HH:MM:SS`; negative durations read as zero.
String formatRecordingTime(Duration d) {
  final s = d.isNegative ? 0 : d.inSeconds;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(s ~/ 3600)}:${two(s ~/ 60 % 60)}:${two(s % 60)}';
}
