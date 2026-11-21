import 'dart:async';
import 'dart:io';

import 'package:simutil_apple/src/usbmux.dart';
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

/// One usbmuxd `Listen` connection: emits on every attach / detach, ends
/// when usbmuxd closes the socket.
Stream<void> _usbmuxListenOnce(String socketPath) {
  Socket? socket;
  late final StreamController<void> controller;
  controller = StreamController<void>(
    onListen: () async {
      try {
        final connected = socket = await connectUsbmuxd(socketPath)
          ..add(usbmuxRequest('Listen'));
        final decoder = UsbmuxDecoder();
        await for (final chunk in connected) {
          for (final message in decoder.add(chunk)) {
            final type = message['MessageType'];
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
