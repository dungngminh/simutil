// Dart-side cost of handing one access unit to the native decoder: the old
// `decode` method call (StandardMethodCodec map) vs the binary message.
//
//   cd app && flutter test benchmark/decode_message_benchmark_test.dart
// ignore_for_file: avoid_print
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_h264/simutil_h264.dart';

void main() {
  test('decode message encoding', () {
    for (final kb in [20, 60, 200]) {
      final au = Uint8List(kb * 1024);
      const codec = StandardMethodCodec();
      final method = _time(
        () =>
            codec.encodeMethodCall(MethodCall('decode', {'id': 7, 'data': au})),
      );
      final binary = _time(() => H264Decoder.message(7, au));
      print(
        '$kb KB access unit: method call ${method.toStringAsFixed(1)} µs, '
        'binary message ${binary.toStringAsFixed(1)} µs',
      );
    }
  });
}

/// Mean microseconds per call over ~1s after a warm-up.
double _time(Object Function() body) {
  for (var i = 0; i < 200; i++) {
    body();
  }
  final watch = Stopwatch()..start();
  var runs = 0;
  while (watch.elapsedMilliseconds < 1000) {
    body();
    runs++;
  }
  return watch.elapsedMicroseconds / runs;
}
