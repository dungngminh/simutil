import 'dart:async';

import 'package:simutil_core/simutil_core.dart';

/// A touch an agent sent to a device, normalized 0..1.
typedef TouchMark = ({String deviceId, TouchPhase phase, double x, double y});

/// Touches sent by agents (MCP taps, swipes, scenarios), so stream tiles can
/// show where they land. The user's own pointer is not reported.
class TouchMarks {
  final _controller = StreamController<TouchMark>.broadcast(sync: true);

  /// Reports a touch on [deviceId].
  void add(String deviceId, TouchPhase phase, double x, double y) =>
      _controller.add((deviceId: deviceId, phase: phase, x: x, y: y));

  /// Touches on [deviceId].
  Stream<TouchMark> of(String deviceId) =>
      _controller.stream.where((m) => m.deviceId == deviceId);

  Future<void> dispose() => _controller.close();
}
