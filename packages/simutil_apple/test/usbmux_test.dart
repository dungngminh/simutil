import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:simutil_apple/src/usbmux.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:test/test.dart';

void main() {
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

  test('decoder splits frames across chunks', () {
    final decoder = UsbmuxDecoder();
    final bytes = [...frame('Result'), ...frame('Attached')];
    expect(decoder.add(bytes.sublist(0, 20)), isEmpty);
    expect(decoder.add(bytes.sublist(20)).map((m) => m['MessageType']), [
      'Result',
      'Attached',
    ]);
    expect(decoder.add(frame('Detached')).single['MessageType'], 'Detached');
  });

  test('request header carries its length', () {
    final request = usbmuxRequest('Listen');
    final length = ByteData.sublistView(request).getUint32(0, Endian.little);
    expect(length, request.length);
    expect(utf8.decode(request.sublist(16)), contains('<string>Listen'));
  });

  test('plist round trip escapes text', () {
    final plist = encodePlist({'Name': 'A & <B>', 'Port': 62078, 'On': true});
    expect(decodePlist(plist), {'Name': 'A & <B>', 'Port': 62078, 'On': true});
  });

  test('decodes nested plists', () {
    final plist = decodePlist('''
<plist version="1.0"><dict>
  <key>DeviceList</key><array><dict>
    <key>DeviceID</key><integer>7</integer>
    <key>Properties</key><dict><key>SerialNumber</key><string>X</string></dict>
  </dict></array>
  <key>Data</key><data>AQI=</data>
  <key>Off</key><false/>
</dict></plist>''');
    expect(plist['DeviceList'], [
      {
        'DeviceID': 7,
        'Properties': {'SerialNumber': 'X'},
      },
    ]);
    expect(plist['Data'], [1, 2]);
    expect(plist['Off'], isFalse);
  });

  test('device from lockdown values, falling back to the serial', () {
    final device = usbmuxDevice(
      {'SerialNumber': '00008120001250920280201E'},
      {
        'DeviceName': 'My iPhone',
        'ProductVersion': '26.1',
        'UniqueDeviceID': '00008120-001250920280201E',
      },
    );
    expect(device.id, '00008120-001250920280201E');
    expect(device.name, 'My iPhone');
    expect(device.platform, 'iOS 26.1');
    expect(device.type, DeviceType.physical);
    expect(device.state, DeviceState.booted);
    expect(usbmuxDevice({'SerialNumber': 'S'}, {}).id, 'S');
  });

  group('against a fake usbmuxd', () {
    late Directory dir;
    late ServerSocket server;
    late String socketPath;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('usbmux');
      socketPath = '${dir.path}/usbmuxd';
      server =
          await ServerSocket.bind(
              InternetAddress(socketPath, type: InternetAddressType.unix),
              0,
            )
            ..listen(_fakeUsbmuxd);
    });

    tearDown(() async {
      await server.close();
      await dir.delete(recursive: true);
    });

    test('lists each device once, named by lockdownd', () async {
      final devices = await listUsbmuxDevices(socketPath: socketPath);
      expect(devices, hasLength(1));
      expect(devices!.single.id, '00008120-001250920280201E');
      expect(devices.single.name, 'Dũng’s iPhone');
      expect(devices.single.platform, 'iOS 26.1');
    });

    test('reads lockdown values by UDID', () async {
      final values = await lockdownValues(
        '00008120-001250920280201E',
        socketPath: socketPath,
      );
      expect(values?['ProductType'], 'iPhone15,2');
      expect(await lockdownValues('other', socketPath: socketPath), isNull);
    });
  });

  test('null when usbmuxd is unreachable', () async {
    expect(await listUsbmuxDevices(socketPath: '/nonexistent/usbmuxd'), isNull);
  });
}

/// Answers `ListDevices` with one device on USB and Wi-Fi, and `Connect`
/// to its lockdownd with the device's values.
void _fakeUsbmuxd(Socket client) {
  final decoder = UsbmuxDecoder();
  var tunnel = false;
  client.listen((chunk) {
    if (tunnel) {
      // lockdownd GetValue: answer whatever the request.
      client.add(
        _lockdownReply({
          'DeviceName': 'Dũng’s iPhone',
          'ProductType': 'iPhone15,2',
          'ProductVersion': '26.1',
          'UniqueDeviceID': '00008120-001250920280201E',
        }),
      );
      return;
    }
    for (final message in decoder.add(chunk)) {
      switch (message['MessageType']) {
        case 'ListDevices':
          client.add(_usbmuxReply(_deviceList));
        case 'Connect':
          // Lockdownd's port in network order, on the USB entry.
          final ok =
              message['PortNumber'] == 0x7EF2 && message['DeviceID'] == 3;
          client.add(_usbmuxReply(_result(ok ? 0 : 3)));
          tunnel = ok;
      }
    }
  });
}

String _device(int id, String type) =>
    '<dict><key>DeviceID</key><integer>$id</integer>'
    '<key>Properties</key><dict>'
    '<key>ConnectionType</key><string>$type</string>'
    '<key>DeviceID</key><integer>$id</integer>'
    '<key>SerialNumber</key><string>00008120001250920280201E</string>'
    '</dict></dict>';

final _deviceList =
    '<plist><dict><key>DeviceList</key><array>'
    '${_device(9, 'Network')}${_device(3, 'USB')}'
    '</array></dict></plist>';

String _result(int number) =>
    '<plist><dict><key>MessageType</key><string>Result</string>'
    '<key>Number</key><integer>$number</integer></dict></plist>';

Uint8List _usbmuxReply(String plist) {
  final body = utf8.encode(plist);
  final header = ByteData(16)..setUint32(0, 16 + body.length, Endian.little);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...body]);
}

Uint8List _lockdownReply(Map<String, String> values) {
  final entries = values.entries
      .map((e) => '<key>${e.key}</key><string>${e.value}</string>')
      .join();
  final body = utf8.encode(
    '<plist><dict><key>Value</key><dict>$entries</dict></dict></plist>',
  );
  final header = ByteData(4)..setUint32(0, body.length);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...body]);
}
