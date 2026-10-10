// Throughput of the scrcpy video socket path: parsing framed packets out of
// socket-sized chunks and prefixing key frames with SPS/PPS.
//
//   dart run benchmark/scrcpy_video_benchmark.dart
// ignore_for_file: avoid_print
import 'dart:math';
import 'dart:typed_data';

import 'package:simutil_adb/src/scrcpy/scrcpy_protocol.dart';

void main() {
  final stream = _stream(frames: 600, seed: 1);
  for (final chunk in [16 * 1024, 64 * 1024]) {
    _run('parse ${chunk ~/ 1024}KB chunks', () {
      final parser = ScrcpyVideoParser();
      var count = 0;
      for (var i = 0; i < stream.length; i += chunk) {
        count += parser
            .add(
              Uint8List.sublistView(stream, i, min(i + chunk, stream.length)),
            )
            .length;
      }
      return count;
    }, bytes: stream.length);
  }

  final config = Uint8List(40);
  final key = Uint8List(200 * 1024);
  _run('key frame prefix', () {
    var n = 0;
    for (var i = 0; i < 100; i++) {
      n += ScrcpyProtocol.withConfig(config, key).length;
    }
    return n;
  }, bytes: 100 * key.length);
}

/// Times [body] over ~2s after a warm-up and prints MB/s.
void _run(String name, int Function() body, {required int bytes}) {
  for (var i = 0; i < 5; i++) {
    body();
  }
  final watch = Stopwatch()..start();
  var runs = 0;
  while (watch.elapsedMilliseconds < 2000) {
    body();
    runs++;
  }
  final seconds = watch.elapsedMicroseconds / 1e6;
  final mbps = bytes * runs / seconds / 1e6;
  print(
    '$name: ${mbps.toStringAsFixed(0)} MB/s '
    '(${(seconds / runs * 1e3).toStringAsFixed(2)} ms/run)',
  );
}

/// Codec id, a session packet, config, then [frames] packets of 60 fps
/// screen-like sizes (one 200 KB key frame, 5-60 KB deltas).
Uint8List _stream({required int frames, required int seed}) {
  final random = Random(seed);
  final out = BytesBuilder();
  void header(int ptsAndFlags, int size) => out.add(
    (ByteData(12)
          ..setUint64(0, ptsAndFlags)
          ..setUint32(8, size))
        .buffer
        .asUint8List(),
  );
  out
    ..add(
      (ByteData(
        4,
      )..setUint32(0, ScrcpyProtocol.codecH264)).buffer.asUint8List(),
    )
    ..add(
      (ByteData(12)
            ..setUint32(0, 0x80000000)
            ..setUint32(4, 1080)
            ..setUint32(8, 2400))
          .buffer
          .asUint8List(),
    );
  header(1 << 62, 40);
  out.add(Uint8List(40));
  for (var i = 0; i < frames; i++) {
    final size = i == 0 ? 200 * 1024 : 5 * 1024 + random.nextInt(55 * 1024);
    header((i == 0 ? 1 << 61 : 0) | i * 16666, size);
    out.add(Uint8List(size));
  }
  return out.takeBytes();
}
