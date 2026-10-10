import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/stream/android/scrcpy_protocol.dart';

void main() {
  test('touch matches scrcpy serialize test layout', () {
    final bytes = ScrcpyProtocol.touch(
      action: 0,
      x: 100,
      y: 200,
      width: 1080,
      height: 1920,
    );
    expect(bytes, hasLength(32));
    expect(bytes.sublist(0, 2), [2, 0]);
    expect(bytes.sublist(10, 22), [
      0,
      0,
      0,
      0x64,
      0,
      0,
      0,
      0xc8,
      0x04,
      0x38,
      0x07,
      0x80,
    ]);
    expect(bytes.sublist(22, 24), [0xff, 0xff]);
  });

  test('keycode is 14 bytes', () {
    expect(ScrcpyProtocol.keycode(1, 66), [
      0,
      1,
      0,
      0,
      0,
      0x42,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
    ]);
  });

  test('parser splits codec, session and packets across chunks', () {
    final b = BytesBuilder()
      ..add(_u32(ScrcpyProtocol.codecH264))
      ..add([..._u32(0x80000000), ..._u32(720), ..._u32(1280)])
      ..add([..._u64(1 << 62), ..._u32(3), 1, 2, 3])
      ..add([..._u64(42), ..._u32(2), 9, 9]);
    final bytes = b.takeBytes();

    final parser = ScrcpyVideoParser();
    final items = [
      ...parser.add(bytes.sublist(0, 7)),
      ...parser.add(bytes.sublist(7, 30)),
      ...parser.add(bytes.sublist(30)),
    ];

    expect(parser.codec, ScrcpyProtocol.codecH264);
    expect(items, hasLength(3));
    expect((items[0] as ScrcpySession).height, 1280);
    expect((items[1] as ScrcpyPacket).config, isTrue);
    expect((items[1] as ScrcpyPacket).data, [1, 2, 3]);
    expect((items[2] as ScrcpyPacket).config, isFalse);
  });
}

List<int> _u32(int v) => (ByteData(4)..setUint32(0, v)).buffer.asUint8List();
List<int> _u64(int v) => (ByteData(8)..setUint64(0, v)).buffer.asUint8List();
