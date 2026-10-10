import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_app/src/devices/slim_mode_cubit.dart';
import 'package:simutil_app/src/mcp/tools/input_tools.dart';
import 'package:simutil_app/src/mcp/tools/tool_context.dart';
import 'package:simutil_app/src/recording/grid_recorder.dart';
import 'package:simutil_app/src/settings/view_settings_cubit.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_core/testing.dart';

/// Slims after a short delay and remembers how many ran at once.
class _FakeSlim implements SlimControl {
  final slimmed = <String>{};
  final calls = <String>[];
  var _running = 0;
  var maxConcurrent = 0;

  @override
  Future<bool> isSlim(String udid) async => slimmed.contains(udid);

  @override
  Future<void> setSlim(String udid, {required bool slim}) async {
    calls.add(udid);
    _running++;
    if (_running > maxConcurrent) maxConcurrent = _running;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    _running--;
    slim ? slimmed.add(udid) : slimmed.remove(udid);
  }
}

class _Session implements DeviceSession {
  _Session(this.deviceId);

  @override
  final String deviceId;

  final touches = <TouchPhase>[];

  @override
  SessionStatus get status => const SessionLive(width: 1, height: 2);

  @override
  Stream<SessionStatus> get statusChanges => Stream.value(status);

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void touch(TouchPhase phase, double x, double y) => touches.add(phase);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Device _sim(String id) => Device.ios(
  id: id,
  name: id,
  state: DeviceState.booted,
  type: DeviceType.simulator,
);

Device _android(String id) => Device.android(
  id: id,
  name: id,
  state: DeviceState.booted,
  type: DeviceType.simulator,
);

void main() {
  late _FakeSlim slim;
  late DevicesCubit devices;
  late StreamsCubit streams;
  late SlimModeCubit mode;
  late Map<String, _Session> sessions;
  late List<DeviceNotice> notices;
  String? failing;

  setUp(() async {
    slim = _FakeSlim();
    devices = DevicesCubit(
      android: FakeDeviceService(simulators: [_android('pixel')]),
      ios: FakeDeviceService(simulators: [_sim('a'), _sim('b')]),
      slim: slim,
      loadIos: true,
    );
    await devices.refresh();
    notices = [];
    devices.notices.listen(notices.add);
    sessions = {};
    streams = StreamsCubit((device) async {
      if (device.id == failing) throw StateError('no stream');
      return sessions[device.id] = _Session(device.id);
    });
    mode = SlimModeCubit(devices: devices, streams: streams);
    failing = null;
  });

  tearDown(() async {
    await mode.close();
    await streams.close();
    await devices.close();
  });

  Future<Map<String, Object?>> run(Map<String, Object?> args) async {
    final context = ToolContext(
      devices: devices,
      streams: streams,
      grid: GridRecorderCubit(),
      view: ViewSettingsCubit(),
      slim: mode,
      adbPath: () => 'adb',
    );
    final tool = inputTools(
      context,
    ).firstWhere((t) => t.name == 'run_scenario');
    final content = await tool.handler(args);
    await pumpEventQueue(); // notices are delivered asynchronously
    return jsonDecode(content.single['text']! as String)
        as Map<String, Object?>;
  }

  const tapSteps = [
    {'action': 'tap', 'x': 0.5, 'y': 0.5},
    {'action': 'swipe', 'x1': 0, 'y1': 0, 'x2': 1, 'y2': 1, 'duration_ms': 50},
  ];

  test('slims simulators in parallel, then runs every device', () async {
    final result = await run({
      'devices': ['a', 'b', 'pixel'],
      'steps': tapSteps,
    });

    expect(slim.calls.toSet(), {'a', 'b'}); // Android untouched
    expect(slim.maxConcurrent, 2);
    final rows = (result['devices']! as List).cast<Map<String, Object?>>();
    expect(rows.map((r) => r['ok']), everyElement(isTrue));
    expect(rows[0]['slimmed_now'], isTrue);
    expect(rows[2].containsKey('slim'), isFalse);
    expect((rows[0]['steps_ms']! as List), hasLength(2));
    // The swipe follows its 50 ms duration, not a tick count.
    expect((rows[0]['steps_ms']! as List)[1], inInclusiveRange(50, 300));
    expect(sessions['pixel']!.touches.first, TouchPhase.down);
    expect(sessions['pixel']!.touches.last, TouchPhase.up);
    expect(notices.map((n) => n.text), [
      'Slimming 2 simulators (reboot)',
      'Slimming a…',
      'Slimming b…',
      'Scenario done: 3/3',
    ]);
  });

  test('slim: false leaves simulators alone', () async {
    final result = await run({
      'devices': ['a'],
      'steps': tapSteps,
      'slim': false,
    });
    expect(slim.calls, isEmpty);
    final row = (result['devices']! as List).single as Map<String, Object?>;
    expect(row['slim'], isFalse);
    expect(row['slimmed_now'], isFalse);
  });

  test('a device that cannot stream fails alone', () async {
    failing = 'b';
    final result = await run({
      'devices': ['b', 'pixel'],
      'steps': tapSteps,
      'slim': false,
    });
    final rows = (result['devices']! as List).cast<Map<String, Object?>>();
    expect(rows[0], containsPair('ok', false));
    expect(rows[0], containsPair('failed_step', 0));
    expect(rows[1], containsPair('ok', true));
    expect(notices.last, (text: 'Scenario done: 1/2', error: true));
  });
}
