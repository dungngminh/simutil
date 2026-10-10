import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:simutil_core/simutil_core.dart';

/// CoreSimulator's default device set.
String defaultSimulatorDeviceSet([Map<String, String>? environment]) =>
    '${(environment ?? Platform.environment)['HOME']}'
    '/Library/Developer/CoreSimulator/Devices';

final _udid = RegExp(
  r'^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$',
);

/// Whether a file event at [relativePath] (inside the device set) means a
/// simulator changed: its `device.plist` (state, rename), the set's
/// `device_set.plist`, or a device directory appearing / disappearing.
/// Atomic-write temp files and the simulators' own file systems are noise.
bool isSimulatorSetChange(String relativePath) {
  final parts = relativePath.split('/').where((p) => p.isNotEmpty).toList();
  return switch (parts) {
    ['device_set.plist'] => true,
    [final udid] => _udid.hasMatch(udid),
    [final udid, 'device.plist'] => _udid.hasMatch(udid),
    _ => false,
  };
}

/// Signals simulator boots, shutdowns, creations and deletions from
/// CoreSimulator's own writes to [deviceSet] (FSEvents), without polling.
Stream<void> watchSimulatorSet(String deviceSet) {
  final dir = Directory(deviceSet);
  if (!dir.existsSync()) return const Stream.empty();
  return dir
      .watch(recursive: true)
      .where((e) => isSimulatorSetChange(e.path.substring(dir.path.length)));
}

/// usbmuxd's socket on macOS.
const usbmuxdSocket = '/var/run/usbmuxd';

/// The `Listen` request that subscribes to usbmuxd attach / detach events
/// (plist protocol: 16-byte little-endian header, then an XML plist).
Uint8List usbmuxListenRequest({int tag = 1}) {
  final body = utf8.encode(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
    '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
    '<plist version="1.0"><dict>'
    '<key>MessageType</key><string>Listen</string>'
    '<key>ClientVersionString</key><string>simutil</string>'
    '<key>ProgName</key><string>simutil</string>'
    '<key>kLibUSBMuxVersion</key><integer>3</integer>'
    '</dict></plist>',
  );
  final header = ByteData(16)
    ..setUint32(0, 16 + body.length, Endian.little)
    ..setUint32(4, 1, Endian.little) // protocol version: plist
    ..setUint32(8, 8, Endian.little) // message: plist
    ..setUint32(12, tag, Endian.little);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...body]);
}

/// Splits usbmuxd replies into their `MessageType`s (`Result`, `Attached`,
/// `Detached`, `Paired`).
class UsbmuxDecoder {
  final _buffer = BytesBuilder(copy: false);

  static final _messageType = RegExp(
    r'<key>MessageType</key>\s*<string>([^<]*)</string>',
  );

  /// Feeds [chunk]; returns the message types of the frames it finished.
  List<String> add(List<int> chunk) {
    _buffer.add(chunk);
    var data = _buffer.takeBytes();
    final types = <String>[];
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
      types.add(_messageType.firstMatch(plist)?.group(1) ?? '');
      data = data.sublist(length);
    }
    _buffer.add(data);
    return types;
  }
}

/// One usbmuxd `Listen` connection: emits on every attach / detach, ends
/// when usbmuxd closes the socket.
Stream<void> _usbmuxListenOnce(String socketPath) {
  Socket? socket;
  late final StreamController<void> controller;
  controller = StreamController<void>(
    onListen: () async {
      try {
        final connected = socket =
            await Socket.connect(
                InternetAddress(socketPath, type: InternetAddressType.unix),
                0,
              )
              ..add(usbmuxListenRequest());
        final decoder = UsbmuxDecoder();
        await for (final chunk in connected) {
          for (final type in decoder.add(chunk)) {
            if (type == 'Attached' || type == 'Detached') controller.add(null);
          }
        }
      } catch (_) {
        // usbmuxd unavailable: end and let the caller retry later.
      }
      await controller.close();
    },
    onCancel: () => socket?.destroy(),
  );
  return controller.stream;
}

/// Signals Apple device changes without polling: CoreSimulator writes for
/// simulators, usbmuxd attach / detach for physical devices (the transport
/// CoreDevice uses for USB-connected iPhones and iPads).
Stream<void> watchAppleDevices({
  String? deviceSet,
  String socketPath = usbmuxdSocket,
}) => mergeStreams([
  watchSimulatorSet(deviceSet ?? defaultSimulatorDeviceSet()),
  reconnecting(() => _usbmuxListenOnce(socketPath)),
]);
