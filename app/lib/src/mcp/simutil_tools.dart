import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:simutil_core/simutil_core.dart';

import '../devices/devices_cubit.dart';
import '../recording/grid_recorder.dart';
import '../settings/recordings_dir.dart';
import '../stream/streams_cubit.dart';
import 'mcp_server.dart';

/// Tools that let an agent list, start, watch and drive devices.
List<McpTool> simutilTools({
  required DevicesCubit devices,
  required StreamsCubit streams,
  required GridRecorderCubit grid,
  required String Function() adbPath,
}) {
  List<Map<String, Object?>> text(Object value) => [
    {
      'type': 'text',
      'text': value is String
          ? value
          : const JsonEncoder.withIndent('  ').convert(value),
    },
  ];

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

  const deviceArg = {
    'device': {
      'type': 'string',
      'description': 'Device id (adb serial / simulator UDID) or name',
    },
  };
  const point = {'type': 'number', 'minimum': 0, 'maximum': 1};

  return [
    McpTool(
      name: 'list_devices',
      description:
          'Android emulators/devices and iOS simulators/devices with their '
          'state, slim mode and whether they are streamed in SimUtil.',
      handler: (_) async {
        await devices.refresh(silent: true);
        final state = devices.stateValue;
        return text([
          for (final d in state.all)
            {
              'id': d.id,
              'name': d.name,
              'os': d.os.name,
              'type': d.type.name,
              'state': d.state.label,
              'slim': state.slimmed.contains(d.id),
              'streaming': streams.stateValue.isOpen(d.id),
            },
        ]);
      },
    ),
    McpTool(
      name: 'start_device',
      description:
          'Boot an emulator/simulator. headless (default true) skips its own '
          'window and streams it into SimUtil.',
      properties: {
        ...deviceArg,
        'headless': {'type': 'boolean'},
      },
      required: ['device'],
      handler: (args) async {
        final device = find(args);
        final headless = args['headless'] as bool? ?? true;
        if (headless) streams.openWhenBooted(device);
        await devices.launch(device, headless: headless);
        return text('Starting ${device.name}');
      },
    ),
    McpTool(
      name: 'shutdown_device',
      description: 'Shut down an emulator/simulator.',
      properties: deviceArg,
      required: ['device'],
      handler: (args) async {
        final device = find(args);
        await streams.closeStream(device.id);
        await devices.shutdown(device);
        return text('Shut down ${device.name}');
      },
    ),
    McpTool(
      name: 'stream_device',
      description: 'Show a running device in the SimUtil grid.',
      properties: deviceArg,
      required: ['device'],
      handler: (args) async {
        final session = await live(find(args));
        return text('Streaming ${session.deviceId} (${session.status})');
      },
    ),
    McpTool(
      name: 'tap',
      description: 'Tap at x,y normalized to 0..1 of the screen.',
      properties: {...deviceArg, 'x': point, 'y': point},
      required: ['device', 'x', 'y'],
      handler: (args) async {
        final session = await live(find(args));
        final x = (args['x']! as num).toDouble();
        final y = (args['y']! as num).toDouble();
        session.touch(TouchPhase.down, x, y);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        session.touch(TouchPhase.up, x, y);
        return text('Tapped ($x, $y)');
      },
    ),
    McpTool(
      name: 'swipe',
      description: 'Swipe from (x1,y1) to (x2,y2), normalized 0..1.',
      properties: {
        ...deviceArg,
        'x1': point,
        'y1': point,
        'x2': point,
        'y2': point,
        'duration_ms': {'type': 'integer', 'default': 300},
      },
      required: ['device', 'x1', 'y1', 'x2', 'y2'],
      handler: (args) async {
        final session = await live(find(args));
        double n(String k) => (args[k]! as num).toDouble();
        final steps = ((args['duration_ms'] as int? ?? 300) / 16).ceil();
        session.touch(TouchPhase.down, n('x1'), n('y1'));
        for (var i = 1; i <= steps; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 16));
          final t = i / steps;
          session.touch(
            TouchPhase.move,
            n('x1') + (n('x2') - n('x1')) * t,
            n('y1') + (n('y2') - n('y1')) * t,
          );
        }
        session.touch(TouchPhase.up, n('x2'), n('y2'));
        return text('Swiped');
      },
    ),
    McpTool(
      name: 'press_button',
      description: 'Press back (Android), home, recents or lock.',
      properties: {
        ...deviceArg,
        'button': {
          'type': 'string',
          'enum': [for (final b in DeviceButton.values) b.name],
        },
      },
      required: ['device', 'button'],
      handler: (args) async {
        final session = await live(find(args));
        session.press(DeviceButton.values.byName(args['button']! as String));
        return text('Pressed ${args['button']}');
      },
    ),
    McpTool(
      name: 'screenshot',
      description: 'PNG screenshot of a running device.',
      properties: deviceArg,
      required: ['device'],
      handler: (args) async {
        final device = find(args);
        final png = await _screenshot(device, adbPath());
        return [
          {'type': 'image', 'data': base64Encode(png), 'mimeType': 'image/png'},
        ];
      },
    ),
    McpTool(
      name: 'record_device',
      description:
          'Start or stop recording a device to ~/Movies/SimUtil '
          '(~/Videos/SimUtil). Returns the file when stopping.',
      properties: deviceArg,
      required: ['device'],
      handler: (args) async {
        final device = find(args);
        await live(device);
        final path = await streams.toggleRecording(
          device.id,
          recordingsDirectory(),
        );
        return text(path == null ? 'Recording started' : 'Saved $path');
      },
    ),
    McpTool(
      name: 'record_grid',
      description: 'Start or stop recording the whole SimUtil grid.',
      handler: (_) async {
        if (grid.isRecording) return text('Saved ${await grid.stop()}');
        final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
        await grid.start('${recordingsDirectory()}/simutil-grid-$stamp.mp4');
        return text('Recording grid');
      },
    ),
    McpTool(
      name: 'set_slim',
      description:
          'iOS simulator: disable (true) or restore (false) background '
          'services to save memory. Reboots a running simulator.',
      properties: {
        ...deviceArg,
        'slim': {'type': 'boolean'},
      },
      required: ['device', 'slim'],
      handler: (args) async {
        final device = find(args);
        final want = args['slim']! as bool;
        if (devices.stateValue.slimmed.contains(device.id) != want) {
          await devices.toggleSlim(device);
        }
        return text('${device.name} slim: $want');
      },
    ),
  ];
}

/// Screenshots need binary stdout, which CommandExec does not keep.
Future<List<int>> _screenshot(Device device, String adbPath) async {
  if (device.os == DeviceOs.android) {
    final result = await Process.run(adbPath, [
      '-s',
      device.id,
      'exec-out',
      'screencap',
      '-p',
    ], stdoutEncoding: null);
    if (result.exitCode != 0) throw StateError('${result.stderr}');
    return result.stdout as List<int>;
  }
  final file = File(
    '${Directory.systemTemp.path}/simutil-shot-${device.id}.png',
  );
  final result = await Process.run('xcrun', [
    'simctl',
    'io',
    device.id,
    'screenshot',
    '--type=png',
    file.path,
  ]);
  if (result.exitCode != 0) throw StateError('${result.stderr}');
  final bytes = await file.readAsBytes();
  await file.delete();
  return bytes;
}
