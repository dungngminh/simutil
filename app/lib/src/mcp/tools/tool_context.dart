import 'dart:async';
import 'dart:convert';

import 'package:simutil_app/src/devices/slim_mode_cubit.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_app/src/recording/grid_recorder.dart';
import 'package:simutil_app/src/settings/view_settings_cubit.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_core/simutil_core.dart';

/// `device` argument shared by tools that act on one device.
const deviceArg = {
  'device': {
    'type': 'string',
    'description': 'Device id (adb serial / simulator UDID) or name',
  },
};

/// Schema of a coordinate normalized to 0..1.
const point = {'type': 'number', 'minimum': 0, 'maximum': 1};

/// App state the MCP tools read and drive, plus helpers they share.
class ToolContext {
  const ToolContext({
    required this.devices,
    required this.streams,
    required this.grid,
    required this.view,
    required this.slim,
    required this.adbPath,
  });

  final DevicesCubit devices;
  final StreamsCubit streams;
  final GridRecorderCubit grid;
  final ViewSettingsCubit view;
  final SlimModeCubit slim;
  final String Function() adbPath;

  /// MCP text content: [value] as is when a String, else pretty JSON.
  List<Map<String, Object?>> text(Object value) => [
    {
      'type': 'text',
      'text': value is String
          ? value
          : const JsonEncoder.withIndent('  ').convert(value),
    },
  ];

  /// The device named by `args['device']` (id or name).
  Device find(Map<String, Object?> args) {
    final id = args['device'] as String? ?? '';
    for (final d in devices.stateValue.all) {
      if (d.id == id || d.name == id) return d;
    }
    throw ArgumentError('Unknown device "$id"; call list_devices');
  }

  /// Opens a stream when needed and waits until input works.
  Future<DeviceSession> live(Device device) async {
    if (!streams.stateValue.isOpen(device.id)) await streams.open(device);
    final session = streams.sessionFor(device.id);
    if (session == null) throw StateError('Could not stream ${device.name}');
    if (session.status is! SessionLive) {
      await session.statusChanges
          .firstWhere((s) => s is SessionLive || s is SessionFailed)
          .timeout(const Duration(seconds: 30));
    }
    if (session.status case SessionFailed(:final message)) {
      throw StateError(message);
    }
    return session;
  }

  /// Seconds the device has been recording; null when not recording.
  int? recordingSeconds(String deviceId) {
    final since = streams.stateValue.entries
        .where((e) => e.device.id == deviceId)
        .firstOrNull
        ?.recordingSince;
    return since == null ? null : DateTime.now().difference(since).inSeconds;
  }
}
