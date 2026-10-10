import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:simutil_core/simutil_core.dart';

/// Splits `adb track-devices` output into device-list snapshots: each frame
/// is a 4-digit hex length followed by that many bytes (`0000` = no
/// devices). adb sends one frame on connect and one per change.
class AdbTrackDevicesDecoder {
  final _buffer = StringBuffer();

  /// Feeds [chunk]; returns the complete frames it finished.
  List<String> add(String chunk) {
    _buffer.write(chunk);
    var data = _buffer.toString();
    final frames = <String>[];
    while (data.length >= 4) {
      final length = int.tryParse(data.substring(0, 4), radix: 16);
      if (length == null) {
        data = ''; // not the framing we know: drop and resync next frame
        break;
      }
      if (data.length < 4 + length) break;
      frames.add(data.substring(4, 4 + length));
      data = data.substring(4 + length);
    }
    _buffer
      ..clear()
      ..write(data);
    return frames;
  }
}

/// One `adb track-devices` run as a stream of snapshots; ends when adb
/// exits. Long-lived, so it uses `Process.start` (not `CommandExec`).
Stream<String> _trackDevicesOnce(String adbPath) {
  Process? process;
  late final StreamController<String> controller;
  controller = StreamController<String>(
    onListen: () async {
      try {
        final started = process = await Process.start(adbPath, [
          'track-devices',
        ]);
        unawaited(started.stdin.close());
        unawaited(started.stderr.drain<void>());
        final decoder = AdbTrackDevicesDecoder();
        await started.stdout
            .transform(utf8.decoder)
            .expand(decoder.add)
            .forEach(controller.add);
      } catch (_) {
        // adb missing or failed: end and let the caller retry later.
      }
      await controller.close();
    },
    onCancel: () => process?.kill(),
  );
  return controller.stream;
}

/// Signals Android device changes without polling: `adb track-devices`
/// (running emulators and devices, kept alive across adb server restarts)
/// plus the AVD directory (emulators created or deleted).
Stream<void> watchAndroidDevices({
  required String adbPath,
  required String avdHome,
}) => mergeStreams([
  reconnecting(() => _trackDevicesOnce(adbPath)),
  _watchAvdHome(avdHome),
]);

Stream<void> _watchAvdHome(String avdHome) {
  final dir = Directory(avdHome);
  if (!dir.existsSync()) return const Stream.empty();
  return dir.watch().where((e) => e.path.endsWith('.ini'));
}
