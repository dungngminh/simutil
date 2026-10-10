import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/stream/android/ts_muxer.dart';

void main() {
  test('crc32Mpeg matches the reference check value', () {
    expect(crc32Mpeg('123456789'.codeUnits), 0x0376E6E7);
  });

  test('frames are whole 188-byte packets with sync bytes', () {
    final muxer = TsMuxer();
    for (final size in [1, 175, 176, 177, 183, 184, 185, 5000]) {
      final ts = muxer.frame(Uint8List(size), pts90k: 9000, keyFrame: size == 1);
      expect(ts.length % 188, 0, reason: 'size $size');
      for (var i = 0; i < ts.length; i += 188) {
        expect(ts[i], 0x47, reason: 'size $size packet ${i ~/ 188}');
      }
    }
  });
}
