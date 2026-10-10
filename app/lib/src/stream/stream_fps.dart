import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:simutil_core/simutil_core.dart';

/// Reads the total frames shown so far for a session's texture.
typedef FrameCounter = Future<int> Function();

/// Frames per second actually shown for [session], updated about once a
/// second while listened to; 0 until frames arrive.
ValueListenable<double> streamFps(DeviceSession session) =>
    _fps[session] ??= _FpsNotifier();

/// Sets where [streamFps] reads [session]'s frame count.
void setFrameCounter(DeviceSession session, FrameCounter counter) =>
    (_fps[session] ??= _FpsNotifier()).counter = counter;

/// Detaches [counter] (its view went away) unless another replaced it.
void removeFrameCounter(DeviceSession session, FrameCounter counter) {
  final notifier = _fps[session];
  if (notifier != null && notifier._counter == counter) notifier.counter = null;
}

final _fps = Expando<_FpsNotifier>();

/// Polls its counter once a second, only while someone listens.
class _FpsNotifier extends ValueNotifier<double> {
  _FpsNotifier() : super(0);

  FrameCounter? _counter;
  Timer? _timer;
  int? _lastCount;
  final _clock = Stopwatch();

  set counter(FrameCounter? counter) {
    _counter = counter;
    _lastCount = null;
    if (counter == null) value = 0;
    _schedule();
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _schedule();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _schedule();
  }

  /// Polls only while listened to and attached to a counter.
  void _schedule() {
    if (hasListeners && _counter != null) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _poll());
    } else {
      _timer?.cancel();
      _timer = null;
      _lastCount = null;
    }
  }

  Future<void> _poll() async {
    final counter = _counter;
    if (counter == null) return;
    final int count;
    try {
      count = await counter();
    } catch (_) {
      return;
    }
    if (_counter != counter) return;
    final last = _lastCount;
    final seconds = _clock.elapsedMicroseconds / 1e6;
    _clock
      ..reset()
      ..start();
    _lastCount = count;
    if (last != null && seconds > 0 && _timer != null) {
      value = ((count - last) / seconds).clamp(0, double.infinity);
    }
  }
}
