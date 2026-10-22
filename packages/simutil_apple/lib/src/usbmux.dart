import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:simutil_core/simutil_core.dart';
import 'package:xml/xml.dart';

/// usbmuxd's socket on macOS.
const usbmuxdSocket = '/var/run/usbmuxd';

/// lockdownd's port on the device, reached through usbmuxd `Connect`.
const _lockdownPort = 62078;

/// A usbmuxd request (plist protocol: 16-byte little-endian header, then an
/// XML plist) of [messageType] with extra [fields].
Uint8List usbmuxRequest(
  String messageType, {
  Map<String, Object> fields = const {},
  int tag = 1,
}) {
  final body = utf8.encode(
    encodePlist({
      'MessageType': messageType,
      'ClientVersionString': 'simutil',
      'ProgName': 'simutil',
      'kLibUSBMuxVersion': 3,
      ...fields,
    }),
  );
  final header = ByteData(16)
    ..setUint32(0, 16 + body.length, Endian.little)
    ..setUint32(4, 1, Endian.little) // protocol version: plist
    ..setUint32(8, 8, Endian.little) // message: plist
    ..setUint32(12, tag, Endian.little);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...body]);
}

/// A lockdownd request: 4-byte big-endian length, then an XML plist.
Uint8List lockdownRequest(Map<String, Object> message) {
  final body = utf8.encode(encodePlist(message));
  final header = ByteData(4)..setUint32(0, body.length);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...body]);
}

/// XML plist of a flat [dict] of strings, integers and booleans.
String encodePlist(Map<String, Object> dict) {
  final entries = dict.entries.map((e) {
    final value = switch (e.value) {
      final bool b => b ? '<true/>' : '<false/>',
      final int i => '<integer>$i</integer>',
      final v => '<string>${_escape('$v')}</string>',
    };
    return '<key>${_escape(e.key)}</key>$value';
  });
  return '<?xml version="1.0" encoding="UTF-8"?>'
      '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
      '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
      '<plist version="1.0"><dict>${entries.join()}</dict></plist>';
}

String _escape(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// The top-level dict of an XML plist, empty when it is anything else.
Map<String, Object?> decodePlist(String xml) {
  final root = XmlDocument.parse(xml).rootElement;
  final value = root.childElements.map(_plistValue).firstOrNull;
  return value is Map<String, Object?> ? value : const {};
}

Object? _plistValue(XmlElement e) => switch (e.localName) {
  'dict' => _plistDict(e.childElements.toList()),
  'array' => e.childElements.map(_plistValue).toList(),
  'string' || 'date' => e.innerText,
  'integer' => int.tryParse(e.innerText.trim()),
  'real' => double.tryParse(e.innerText.trim()),
  'true' => true,
  'false' => false,
  'data' => base64Decode(e.innerText.replaceAll(RegExp(r'\s'), '')),
  _ => null,
};

Map<String, Object?> _plistDict(List<XmlElement> children) => {
  for (var i = 0; i + 1 < children.length; i += 2)
    children[i].innerText: _plistValue(children[i + 1]),
};

/// Splits usbmuxd replies into their plist dicts (`Result`, `Attached`,
/// `Detached`, `Paired`, `DeviceList`).
class UsbmuxDecoder {
  final _buffer = BytesBuilder(copy: false);

  /// Feeds [chunk]; returns the messages of the frames it finished.
  List<Map<String, Object?>> add(List<int> chunk) {
    _buffer.add(chunk);
    var data = _buffer.takeBytes();
    final messages = <Map<String, Object?>>[];
    while (data.length >= 16) {
      final length = ByteData.sublistView(
        data,
        0,
        4,
      ).getUint32(0, Endian.little);
      if (length < 16) {
        data = Uint8List(0); // corrupt: drop and wait for the reconnect
        break;
      }
      if (data.length < length) break;
      final plist = utf8.decode(data.sublist(16, length), allowMalformed: true);
      try {
        messages.add(decodePlist(plist));
      } on XmlException {
        messages.add(const {});
      }
      data = data.sublist(length);
    }
    _buffer.add(data);
    return messages;
  }
}

/// Opens a connection to usbmuxd at [socketPath].
Future<Socket> connectUsbmuxd(String socketPath) => Socket.connect(
  InternetAddress(socketPath, type: InternetAddressType.unix),
  0,
);

/// Physical Apple devices usbmuxd knows (USB, or Wi-Fi when paired for
/// network sync), named and versioned by each device's lockdownd.
///
/// Null when usbmuxd or a device's lockdownd does not answer within
/// [timeout], so callers can fall back to `devicectl`.
Future<List<Device>?> listUsbmuxDevices({
  String socketPath = usbmuxdSocket,
  Duration timeout = const Duration(seconds: 5),
}) async {
  try {
    final devices = <Device>[];
    for (final props in await _attachedDevices(socketPath).timeout(timeout)) {
      final values = await _lockdownValues(
        socketPath,
        props['DeviceID']! as int,
      ).timeout(timeout);
      devices.add(usbmuxDevice(props, values));
    }
    return devices;
  } catch (e) {
    log('listUsbmuxDevices: $e');
    return null;
  }
}

/// lockdownd values (`DeviceName`, `ProductType`, `ProductVersion`, ...) of
/// the device [udid], or null when usbmuxd does not have it.
Future<Map<String, Object?>?> lockdownValues(
  String udid, {
  String socketPath = usbmuxdSocket,
  Duration timeout = const Duration(seconds: 5),
}) async {
  try {
    final serial = _serial(udid);
    final props = (await _attachedDevices(socketPath).timeout(
      timeout,
    )).where((p) => _serial('${p['SerialNumber']}') == serial).firstOrNull;
    if (props == null) return null;
    return await _lockdownValues(
      socketPath,
      props['DeviceID']! as int,
    ).timeout(timeout);
  } catch (e) {
    log('lockdownValues: $e');
    return null;
  }
}

/// A [Device] from usbmuxd device [properties] and lockdownd [values].
/// Pure function (no I/O) so it is unit-testable on any platform.
Device usbmuxDevice(
  Map<String, Object?> properties,
  Map<String, Object?> values,
) {
  final version = values['ProductVersion'] as String?;
  return Device.ios(
    id: values['UniqueDeviceID'] as String? ?? '${properties['SerialNumber']}',
    name: values['DeviceName'] as String? ?? '',
    platform: version == null ? null : 'iOS $version',
    type: DeviceType.physical,
    state: DeviceState.booted,
  );
}

/// Serial numbers compared without the dash newer UDIDs carry.
String _serial(String udid) => udid.replaceAll('-', '').toUpperCase();

/// usbmuxd `ListDevices` properties, one per device: a device on both USB
/// and Wi-Fi is listed twice, and keeps its USB entry.
Future<List<Map<String, Object?>>> _attachedDevices(String socketPath) async {
  final socket = await connectUsbmuxd(socketPath);
  try {
    final reader = _UsbmuxReader(socket)..send(usbmuxRequest('ListDevices'));
    final reply = await reader.next();
    final all = [
      for (final entry in reply['DeviceList'] as List? ?? const [])
        if ((entry as Map)['Properties'] case final Map props)
          props.cast<String, Object?>(),
    ]..sort((a, b) => _rank(a) - _rank(b));
    final seen = <String>{};
    return [
      for (final props in all)
        if (seen.add(_serial('${props['SerialNumber']}'))) props,
    ];
  } finally {
    socket.destroy();
  }
}

int _rank(Map<String, Object?> props) =>
    props['ConnectionType'] == 'USB' ? 0 : 1;

/// lockdownd's `GetValue` (no session, so no pairing record needed) on the
/// usbmuxd device [deviceId].
Future<Map<String, Object?>> _lockdownValues(
  String socketPath,
  int deviceId,
) async {
  final socket = await connectUsbmuxd(socketPath);
  try {
    final reader = _UsbmuxReader(socket)
      ..send(
        usbmuxRequest(
          'Connect',
          fields: {
            'DeviceID': deviceId,
            // usbmuxd wants the port in network byte order.
            'PortNumber': ((_lockdownPort & 0xff) << 8) | (_lockdownPort >> 8),
          },
        ),
      );
    final result = await reader.next();
    if (result['Number'] != 0) {
      throw StateError('usbmuxd Connect failed: ${result['Number']}');
    }
    // The socket is now a raw tunnel to lockdownd.
    reader.send(lockdownRequest({'Label': 'simutil', 'Request': 'GetValue'}));
    final length = ByteData.sublistView(await reader.read(4)).getUint32(0);
    final reply = decodePlist(utf8.decode(await reader.read(length)));
    if (reply['Value'] case final Map values) {
      return values.cast<String, Object?>();
    }
    throw StateError('lockdownd GetValue failed: ${reply['Error']}');
  } finally {
    socket.destroy();
  }
}

/// Exact-length reads over a usbmuxd socket.
class _UsbmuxReader {
  _UsbmuxReader(this._socket) {
    _socket.listen(
      (chunk) {
        _bytes = Uint8List.fromList([..._bytes, ...chunk]);
        _wake();
      },
      onError: (Object _) => _closed(),
      onDone: _closed,
      cancelOnError: true,
    );
  }

  final Socket _socket;
  var _bytes = Uint8List(0);
  var _done = false;
  Completer<void>? _more;

  void send(List<int> bytes) => _socket.add(bytes);

  /// The next usbmuxd reply.
  Future<Map<String, Object?>> next() async {
    final header = await read(16);
    final length = ByteData.sublistView(header).getUint32(0, Endian.little);
    return decodePlist(utf8.decode(await read(length - 16)));
  }

  Future<Uint8List> read(int length) async {
    while (_bytes.length < length) {
      if (_done) throw const SocketException('usbmuxd closed the connection');
      await (_more = Completer<void>()).future;
    }
    final out = Uint8List.fromList(_bytes.sublist(0, length));
    _bytes = Uint8List.fromList(_bytes.sublist(length));
    return out;
  }

  void _closed() {
    _done = true;
    _wake();
  }

  void _wake() {
    _more?.complete();
    _more = null;
  }
}
