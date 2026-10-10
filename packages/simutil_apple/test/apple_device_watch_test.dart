import 'dart:convert';
import 'dart:typed_data';

import 'package:simutil_apple/src/apple_device_watch.dart';
import 'package:test/test.dart';

void main() {
  const udid = '030D9BD6-3A81-49E1-97E5-9B2A8C069EDE';

  test('only device state / set changes count', () {
    expect(isSimulatorSetChange('/$udid/device.plist'), isTrue);
    expect(isSimulatorSetChange('/device_set.plist'), isTrue);
    expect(isSimulatorSetChange('/$udid'), isTrue);
    expect(isSimulatorSetChange('/$udid/device.plist.sb-0248-Ti7oRY'), isFalse);
    expect(isSimulatorSetChange('/$udid/data/Library/x.db'), isFalse);
    expect(isSimulatorSetChange('/.DS_Store'), isFalse);
  });

  Uint8List frame(String type) {
    final body = utf8.encode(
      '<plist><dict><key>MessageType</key><string>$type</string></dict>'
      '</plist>',
    );
    final header = ByteData(16)
      ..setUint32(0, 16 + body.length, Endian.little)
      ..setUint32(4, 1, Endian.little)
      ..setUint32(8, 8, Endian.little);
    return Uint8List.fromList([...header.buffer.asUint8List(), ...body]);
  }

  test('usbmux decoder splits frames across chunks', () {
    final decoder = UsbmuxDecoder();
    final bytes = [...frame('Result'), ...frame('Attached')];
    expect(decoder.add(bytes.sublist(0, 20)), isEmpty);
    expect(decoder.add(bytes.sublist(20)), ['Result', 'Attached']);
    expect(decoder.add(frame('Detached')), ['Detached']);
  });

  test('Listen request header carries its length', () {
    final request = usbmuxListenRequest();
    final length = ByteData.sublistView(request).getUint32(0, Endian.little);
    expect(length, request.length);
    expect(utf8.decode(request.sublist(16)), contains('<string>Listen'));
  });
}
