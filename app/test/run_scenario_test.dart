import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_app/src/devices/slim_mode_cubit.dart';
import 'package:simutil_app/src/mcp/tools/input_tools.dart';
import 'package:simutil_app/src/mcp/tools/tool_context.dart';
import 'package:simutil_app/src/recording/grid_recorder.dart';
import 'package:simutil_app/src/scenarios/scenario_runs_cubit.dart';
import 'package:simutil_app/src/settings/view_settings_cubit.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_app/src/stream/touch_marks.dart';
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
  final downs = <(double, double)>[];

  @override
  SessionStatus get status => const SessionLive(width: 1, height: 2);

  @override
  Stream<SessionStatus> get statusChanges => Stream.value(status);

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void touch(TouchPhase phase, double x, double y) {
    touches.add(phase);
    if (phase == TouchPhase.down) downs.add((x, y));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Each device's elements; records launches and typed text.
class _FakeAutomation implements DeviceAutomation {
  final screens = <String, List<UiElement>>{};
  final launched = <String>[];
  final typed = <String>[];

  /// Whether taps by label go native; records them when they do.
  var native = false;
  final pressed = <String>[];

  @override
  Future<bool> tapElement(Device device, UiElement element) async {
    if (native) pressed.add('${device.id}:${element.label}');
    return native;
  }

  @override
  Future<void> launch(
    Device device,
    String appId, {
    bool clearState = false,
  }) async => launched.add('${device.id}:$appId${clearState ? ' clear' : ''}');

  @override
  Future<void> typeText(Device device, String text) async =>
      typed.add('${device.id}:$text');

  @override
  Future<List<UiElement>> elements(Device device) async =>
      screens[device.id] ?? const [];
}

UiElement _button(String label, double x, double y) => UiElement(
  label: label,
  left: x - 0.05,
  top: y - 0.02,
  right: x + 0.05,
  bottom: y + 0.02,
);

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
  late _FakeAutomation automation;
  late TouchMarks marks;
  late ScenarioRunsCubit runs;

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
    automation = _FakeAutomation();
    marks = TouchMarks();
    runs = ScenarioRunsCubit();
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
      automation: automation,
      marks: marks,
      runs: runs,
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
    // The swipe lasts at least its 50 ms; the ceiling only catches a hang.
    expect((rows[0]['steps_ms']! as List)[1], inInclusiveRange(50, 2000));
    expect(sessions['pixel']!.touches.first, TouchPhase.down);
    expect(sessions['pixel']!.touches.last, TouchPhase.up);
    expect(notices.map((n) => n.text), [
      'Slimming 2 simulators (reboot)',
      'Slimming a…',
      'Slimming b…',
      'Scenario done: 3/3',
    ]);
  });

  test('a non-boolean slim is rejected before anything moves', () async {
    await expectLater(
      run({
        'devices': ['a'],
        'steps': tapSteps,
        'slim': 'false',
      }),
      throwsArgumentError,
    );
    expect(slim.calls, isEmpty);
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

  test('label taps hit each device at its own position', () async {
    automation.screens['a'] = [_button('month', 0.85, 0.18)];
    automation.screens['pixel'] = [
      _button('day', 0.7, 0.13),
      _button('month\nTab 2 of 2', 0.86, 0.13),
    ];
    final result = await run({
      'devices': ['a', 'pixel'],
      'slim': false,
      'steps': [
        {
          'action': 'launch',
          'app': 'com.loggoo',
          'android': 'com.loggoo.dev',
          'clear_state': true,
        },
        {'action': 'tap', 'label': 'Month'},
        {'action': 'tap', 'x': 0.1, 'y': 0.2, 'repeat': 4},
        {'action': 'type', 'text': 'hi'},
      ],
    });
    final rows = (result['devices']! as List).cast<Map<String, Object?>>();
    expect(rows.map((r) => r['ok']), everyElement(isTrue));
    expect(automation.launched, [
      'a:com.loggoo clear',
      'pixel:com.loggoo.dev clear',
    ]);
    expect(sessions['a']!.downs.first.$1, closeTo(0.85, 1e-9));
    expect(sessions['pixel']!.downs.first.$1, closeTo(0.86, 1e-9));
    expect(sessions['a']!.downs, hasLength(5)); // label tap + 4 repeats
    expect(automation.typed, ['a:hi', 'pixel:hi']);
  });

  test('a missing label fails that device after its timeout', () async {
    final result = await run({
      'devices': ['pixel'],
      'steps': [
        {'action': 'tap', 'label': 'nope', 'timeout_ms': 50},
      ],
    });
    final row = (result['devices']! as List).single as Map<String, Object?>;
    expect(row, containsPair('ok', false));
    expect(row['error'], contains('No element "nope"'));
  });

  test('bad repeat and empty launch are rejected up front', () async {
    for (final step in [
      {'action': 'wait', 'ms': 1, 'repeat': 0},
      {'action': 'launch'},
      {'action': 'type'},
    ]) {
      await expectLater(
        run({
          'devices': ['pixel'],
          'steps': [step],
        }),
        throwsArgumentError,
      );
    }
  });

  test('agent taps are reported for the touch dot', () async {
    final seen = <TouchMark>[];
    marks.of('pixel').listen(seen.add);
    await run({
      'devices': ['pixel'],
      'steps': [
        {'action': 'tap', 'x': 0.25, 'y': 0.75},
      ],
    });
    expect(seen.map((m) => (m.phase, m.x, m.y)), [
      (TouchPhase.down, 0.25, 0.75),
      (TouchPhase.up, 0.25, 0.75),
    ]);
  });

  test('swipe from a label repeats until the target shows up', () async {
    automation.screens['pixel'] = [_button('13', 0.4, 0.65)];
    var ups = 0;
    marks.of('pixel').listen((m) {
      if (m.phase == TouchPhase.up && ++ups == 3) {
        automation.screens['pixel']!.add(_button('15:00', 0.5, 0.8));
      }
    });
    final result = await run({
      'devices': ['pixel'],
      'steps': [
        {
          'action': 'swipe',
          'label': '13',
          'dy': -0.05,
          'duration_ms': 20,
          'until': '15:',
        },
      ],
    });
    final row = (result['devices']! as List).single as Map<String, Object?>;
    expect(row, containsPair('ok', true));
    expect(ups, 3);
    expect(sessions['pixel']!.downs.first.$2, closeTo(0.65, 1e-9));
  });

  test('swipe until fails after max swipes', () async {
    automation.screens['pixel'] = [_button('13', 0.4, 0.65)];
    final result = await run({
      'devices': ['pixel'],
      'steps': [
        {
          'action': 'swipe',
          'label': '13',
          'dy': -0.05,
          'duration_ms': 20,
          'until': 'nope',
          'max': 2,
        },
      ],
    });
    final row = (result['devices']! as List).single as Map<String, Object?>;
    expect(row['error'], contains('after 2 swipes'));
    expect(sessions['pixel']!.downs, hasLength(2));
  });

  test('runs record each device: ok, or failed with the step', () async {
    failing = 'b';
    await run({
      'devices': ['b', 'pixel'],
      'slim': false,
      'steps': tapSteps,
    });
    final r = runs.stateValue.single;
    expect(r.steps, ['tap (0.5, 0.5)', 'swipe (0, 0)']);
    expect(r.status, ScenarioStatus.failed);
    // b failed on step 1 (no stream); pixel ran both steps.
    expect(r.stepStatus(0), ScenarioStatus.failed);
    expect(r.stepErrors(0).single.$2, contains('no stream'));
    expect(r.stepStatus(1), ScenarioStatus.ok);
    expect(r.stepErrors(1), isEmpty);
    expect(r.source, contains('- tap: [0.5, 0.5]'));
    expect(r.lines, [2, 3]); // after devices: and steps:
  });

  test(
    'if_visible / if_not_visible skip a step; asserts wait or fail',
    () async {
      automation.screens['pixel'] = [_button('nice', 0.5, 0.7)];
      final result = await run({
        'devices': ['pixel'],
        'steps': [
          {'action': 'tap', 'label': 'nice', 'if_visible': 'nice'},
          {'action': 'tap', 'x': 0.1, 'y': 0.1, 'if_visible': 'gone'},
          {'action': 'tap', 'x': 0.2, 'y': 0.2, 'if_not_visible': 'gone'},
          {'action': 'assert_visible', 'label': 'nice'},
          {'action': 'assert_not_visible', 'label': 'gone'},
        ],
      });
      final row = (result['devices']! as List).single as Map<String, Object?>;
      expect(row, containsPair('ok', true));
      // Ran the first and third taps; skipped the second.
      expect(sessions['pixel']!.downs, [(0.5, 0.7), (0.2, 0.2)]);
      final r = runs.stateValue.single;
      expect(r.stepStatus(0), ScenarioStatus.ok);
      expect(r.stepStatus(1), ScenarioStatus.skipped);
      expect(r.stepStatus(2), ScenarioStatus.ok);
      expect(r.steps[1], 'tap (0.1, 0.1) if "gone" visible');

      final failed = await run({
        'devices': ['pixel'],
        'steps': [
          {'action': 'assert_not_visible', 'label': 'nice', 'timeout_ms': 50},
        ],
      });
      final failedRow =
          (failed['devices']! as List).single as Map<String, Object?>;
      expect(failedRow['error'], contains('"nice" still visible'));
    },
  );

  test(
    'label taps go native when the platform can, still marking the dot',
    () async {
      automation
        ..native = true
        ..screens['pixel'] = [_button('Allow', 0.5, 0.55)];
      final seen = <TouchMark>[];
      marks.of('pixel').listen(seen.add);
      await run({
        'devices': ['pixel'],
        'steps': [
          {'action': 'tap', 'label': 'Allow'},
        ],
      });
      expect(automation.pressed, ['pixel:Allow']);
      expect(sessions['pixel']!.downs, isEmpty); // no coordinate touch
      expect(seen.map((m) => (m.phase, m.y)), [
        (TouchPhase.down, 0.55),
        (TouchPhase.up, 0.55),
      ]);
    },
  );
}
