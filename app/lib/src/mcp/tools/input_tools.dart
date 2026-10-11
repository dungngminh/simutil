import 'dart:async';
import 'dart:math';

import 'package:simutil_app/src/mcp/mcp_server.dart';
import 'package:simutil_app/src/mcp/tools/tool_context.dart';
import 'package:simutil_core/simutil_core.dart';

/// Touch, button and text input, app launch and accessibility lookup, alone
/// or as a scenario across devices.
List<McpTool> inputTools(ToolContext c) => [
  McpTool(
    name: 'tap',
    description:
        'Tap at x,y normalized to 0..1 of the screen, or on the element '
        'whose accessibility label, id or value matches label (exact, else '
        'contains; case-insensitive), waiting up to timeout_ms for it.',
    properties: {...deviceArg, 'x': point, 'y': point, ..._labelArgs},
    required: ['device'],
    handler: (args) async {
      _validateStep({...args, 'action': 'tap'});
      final device = c.find(args);
      final (x, y) = await _tap(c, device, await c.input(device), args);
      return c.text('Tapped ($x, $y)');
    },
  ),
  McpTool(
    name: 'launch_app',
    description:
        'Launch an app by Android package name or iOS bundle id '
        '(e.g. com.example.app).',
    properties: {
      ...deviceArg,
      'app': {'type': 'string'},
    },
    required: ['device', 'app'],
    handler: (args) async {
      final app = args['app'];
      if (app is! String || app.isEmpty) throw ArgumentError('app required');
      await c.automation.launch(c.find(args), app);
      return c.text('Launched $app');
    },
  ),
  McpTool(
    name: 'type_text',
    description:
        'Type text into the focused field (tap the field first). ASCII only '
        'for now.',
    properties: {
      ...deviceArg,
      'text': {'type': 'string'},
    },
    required: ['device', 'text'],
    handler: (args) async {
      _validateStep({...args, 'action': 'type'});
      final device = c.find(args);
      await c.input(device);
      await c.automation.typeText(device, args['text']! as String);
      return c.text('Typed');
    },
  ),
  McpTool(
    name: 'find_elements',
    description:
        "Elements on screen from the device's accessibility tree: label, "
        'id, value, role, center x/y and frame [left, top, right, bottom], '
        'all normalized 0..1. Pass label to keep only matching ones (also by '
        'id; unfiltered, id-only elements are left out). Use the '
        'labels with tap {label} so steps work across screen sizes.',
    properties: {
      ...deviceArg,
      'label': {'type': 'string'},
    },
    required: ['device'],
    handler: (args) async {
      final device = c.find(args);
      await c.live(device);
      final all = await c.automation.elements(device);
      final query = (args['label'] as String?)?.trim().toLowerCase();
      return c.text([
        for (final e in all)
          if (query == null
              // Unfiltered, id-only nodes are mostly layout containers.
              ? e.label.isNotEmpty || e.value.isNotEmpty
              : [
                  e.label,
                  e.id,
                  e.value,
                ].any((s) => s.toLowerCase().contains(query)))
            e.toJson(),
      ]);
    },
  ),
  McpTool(
    name: 'swipe',
    description:
        'Swipe from (x1,y1) to (x2,y2), normalized 0..1; or from the center '
        'of the element named by label by (dx, dy). With until, repeats the '
        'swipe (up to max times) until an element matching until shows up: '
        'scroll a list or a picker wheel to a value.',
    properties: {...deviceArg, ..._swipeArgs, ..._labelArgs},
    required: ['device'],
    handler: (args) async {
      _validateStep({...args, 'action': 'swipe'});
      final device = c.find(args);
      final n = await _swipe(c, device, await c.input(device), args);
      return c.text(n == 1 ? 'Swiped' : 'Swiped $n times');
    },
  ),
  McpTool(
    name: 'press_button',
    description:
        'Press back (Android), home, recents, lock, volumeUp or volumeDown.',
    properties: {...deviceArg, 'button': _buttonSchema},
    required: ['device', 'button'],
    handler: (args) async {
      final b = _button(args);
      (await c.input(c.find(args))).press(b);
      return c.text('Pressed ${b.name}');
    },
  ),
  McpTool(
    name: 'repair_input',
    description:
        'iOS simulator: restore input after Xcode Device Hub took it over '
        '(tap/swipe/press report it). Restarts backboardd, closing open apps.',
    properties: deviceArg,
    required: ['device'],
    handler: (args) async {
      final device = c.find(args);
      await (await c.live(device)).repairInput();
      await c.input(device);
      return c.text('Input restored on ${device.name}');
    },
  ),
  McpTool(
    name: 'run_scenario',
    description:
        'Run the same steps on several devices (Android and iOS) at once. '
        'All devices are readied first, then start together; each runs the '
        'steps in order. iOS simulators not yet slim are slimmed first '
        '(parallel reboot, closes open apps) unless slim is false. '
        'Steps: {action: tap, x, y} or {action: tap, label, timeout_ms?} | '
        '{action: swipe, x1, y1, x2, y2 (or label, dx, dy), until?, max?, '
        'duration_ms?} | '
        '{action: press, button} | {action: wait, ms} | '
        '{action: launch, app} (or android / ios ids per platform) | '
        '{action: type, text}. Any step takes repeat (default 1). '
        'Coordinates are normalized 0..1; prefer label taps (labels from '
        'find_elements) since layouts differ between devices. Returns each '
        "device's outcome with start/end ms from the common start and "
        'per-step ms.',
    properties: {
      'slim': {
        'type': 'boolean',
        'default': true,
        'description': 'Slim iOS simulators before running',
      },
      'devices': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Device ids or names; omit to use every streamed device',
      },
      'steps': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'action': {
              'type': 'string',
              'enum': ['tap', 'swipe', 'press', 'wait', 'launch', 'type'],
            },
            'x': point,
            'y': point,
            ..._swipeArgs,
            'button': _buttonSchema,
            'ms': {'type': 'integer'},
            ..._labelArgs,
            'app': {'type': 'string'},
            'android': {'type': 'string'},
            'ios': {'type': 'string'},
            'text': {'type': 'string'},
            'repeat': {'type': 'integer', 'minimum': 1},
          },
          'required': ['action'],
        },
      },
    },
    required: ['steps'],
    handler: (args) async => c.text(await runScenario(c, args)),
  ),
];

/// A scenario's steps and target devices from `run_scenario` arguments;
/// throws [ArgumentError] on anything malformed, before any device moves.
({List<Map<String, Object?>> steps, List<Device> devices}) parseScenario(
  ToolContext c,
  Map<String, Object?> args,
) {
  final rawSteps = args['steps'];
  if (rawSteps is! List || rawSteps.isEmpty) {
    throw ArgumentError('steps must be a non-empty list');
  }
  final steps = [
    for (final (i, s) in rawSteps.indexed)
      if (s is Map)
        s.cast<String, Object?>()
      else
        throw ArgumentError('step ${i + 1} must be an object'),
  ];
  for (final (i, step) in steps.indexed) {
    try {
      _validateStep(step);
    } on ArgumentError catch (e) {
      throw ArgumentError('step ${i + 1}: ${e.message}');
    }
  }
  final ids = args['devices'];
  if (ids != null && ids is! List) {
    throw ArgumentError('devices must be a list of ids or names');
  }
  final devices = ids == null
      ? [for (final e in c.streams.stateValue.entries) e.device]
      : [
          for (final id in ids as List) c.find({'device': id}),
        ];
  if (devices.isEmpty) {
    throw ArgumentError('No devices: pass devices or stream some first');
  }
  final slim = args['slim'];
  if (slim != null && slim is! bool) {
    throw ArgumentError('slim must be a boolean, got $slim');
  }
  return (steps: steps, devices: devices);
}

/// Runs a scenario (see the run_scenario tool) for an agent or the
/// scenario editor; returns the per-device report.
Future<Map<String, Object?>> runScenario(
  ToolContext c,
  Map<String, Object?> args,
) async {
  final (:steps, devices: targets) = parseScenario(c, args);
  final slim = args['slim'];
  final runId = c.runs?.start(
    {for (final d in targets) d.id: d.name},
    [for (final s in steps) _describe(s)],
  );
  final clock = Stopwatch()..start();
  final slimmedNow = slim == false
      ? const <String>{}
      : await _slimSimulators(c, targets);
  final sessions = await Future.wait([
    for (final device in targets) _ready(c, device),
  ]);
  final prepMs = clock.elapsedMilliseconds;
  // Every session is ready: all devices start from here together.
  clock.reset();
  final results = await Future.wait([
    for (final (i, device) in targets.indexed)
      _runScenario(c, device, sessions[i], steps, clock, runId),
  ]);
  final slimmed = c.devices.stateValue.slimmed;
  for (final (i, device) in targets.indexed) {
    if (device.os == DeviceOs.ios && !device.type.isPhysical) {
      results[i]['slim'] = slimmed.contains(device.id);
      results[i]['slimmed_now'] = slimmedNow.contains(device.id);
    }
  }
  final ok = results.where((r) => r['ok'] == true).length;
  c.devices.notify(
    'Scenario done: $ok/${results.length}',
    error: ok < results.length,
  );
  return {'prep_ms': prepMs, 'devices': results};
}

const _swipeArgs = {
  'x1': point,
  'y1': point,
  'x2': point,
  'y2': point,
  'dx': {'type': 'number', 'description': 'Offset from label, normalized'},
  'dy': {'type': 'number', 'description': 'Offset from label, normalized'},
  'until': {
    'type': 'string',
    'description': 'Repeat until an element matching this label shows up',
  },
  'max': {'type': 'integer', 'default': 20},
  'duration_ms': {'type': 'integer', 'default': 300},
};

const _labelArgs = {
  'label': {
    'type': 'string',
    'description': 'Accessibility label, id or value to tap instead of x,y',
  },
  'timeout_ms': {'type': 'integer', 'default': 5000},
  'index': {
    'type': 'integer',
    'default': 0,
    'description':
        'Which match to tap when several share the label, in screen order; '
        '-1 is the last',
  },
};

final _buttonSchema = {
  'type': 'string',
  'enum': [for (final b in DeviceButton.values) b.name],
};

/// Slims the iOS simulators in [targets] that are not slim yet, rebooting
/// them in parallel; returns the ids that ended up slim.
Future<Set<String>> _slimSimulators(ToolContext c, List<Device> targets) async {
  final slimmed = c.devices.stateValue.slimmed;
  final pending = [
    for (final d in targets)
      if (d.os == DeviceOs.ios && !d.type.isPhysical && !slimmed.contains(d.id))
        d,
  ];
  if (pending.isEmpty) return const {};
  final n = pending.length;
  c.devices.notify('Slimming $n simulator${n == 1 ? '' : 's'} (reboot)');
  await Future.wait([
    // The device then runs unslimmed; its result reports slim: false.
    for (final d in pending)
      c.slim
          .setSlim(d, on: true)
          .catchError(
            (Object e) =>
                c.devices.notify('Slim failed for ${d.name}: $e', error: true),
          ),
  ]);
  final now = c.devices.stateValue.slimmed;
  return {
    for (final d in pending)
      if (now.contains(d.id)) d.id,
  };
}

/// [device]'s session once input works, or why it could not get there.
Future<Object> _ready(ToolContext c, Device device) async {
  try {
    return await c.input(device);
  } catch (e) {
    return e;
  }
}

/// Runs [steps] on [session] (or reports [session]'s setup error), timed by
/// [clock] from the common start; reports where it stopped, never throws.
Future<Map<String, Object?>> _runScenario(
  ToolContext c,
  Device device,
  Object session,
  List<Map<String, Object?>> steps,
  Stopwatch clock,
  int? runId,
) async {
  void finish({String? error}) {
    if (runId != null) {
      c.runs?.finish(
        runId,
        device.id,
        ms: clock.elapsedMilliseconds,
        error: error,
      );
    }
  }

  if (session is! DeviceSession) {
    finish(error: '$session');
    return {
      'device': device.name,
      'ok': false,
      'failed_step': 0,
      'error': '$session',
    };
  }
  final start = clock.elapsedMilliseconds;
  final stepsMs = <int>[];
  try {
    for (final step in steps) {
      final at = clock.elapsedMilliseconds;
      for (var i = 0; i < (step['repeat'] as int? ?? 1); i++) {
        await _runStep(c, device, session, step);
      }
      stepsMs.add(clock.elapsedMilliseconds - at);
      if (runId != null) c.runs?.progress(runId, device.id, stepsMs.length);
    }
    finish();
    return {
      'device': device.name,
      'ok': true,
      'start_ms': start,
      'end_ms': clock.elapsedMilliseconds,
      'steps_ms': stepsMs,
    };
  } catch (e) {
    finish(error: '$e');
    return {
      'device': device.name,
      'ok': false,
      'failed_step': stepsMs.length,
      'error': '$e',
    };
  }
}

/// A scenario step in a few words, for the scenarios panel.
String _describe(Map<String, Object?> step) {
  String q(Object? v) => '"$v"';
  String at() => step['label'] != null
      ? q(step['label'])
      : '(${step['x'] ?? step['x1']}, ${step['y'] ?? step['y1']})';
  final text = switch (step['action']) {
    'tap' => 'tap ${at()}',
    'swipe' =>
      'swipe ${at()}'
          '${step['until'] != null ? ' until ${q(step['until'])}' : ''}',
    'press' => 'press ${step['button']}',
    'wait' => 'wait ${step['ms']} ms',
    'launch' => 'launch ${step['app'] ?? step['android'] ?? step['ios']}',
    'type' => 'type ${q(step['text'])}',
    final other => '$other',
  };
  final repeat = step['repeat'] as int? ?? 1;
  return repeat > 1 ? '$text ×$repeat' : text;
}

/// A normalized coordinate from [args]; throws outside 0..1.
double _coord(Map<String, Object?> args, String key) {
  final v = args[key];
  if (v is! num || v < 0 || v > 1) {
    throw ArgumentError('$key must be a number in 0..1, got $v');
  }
  return v.toDouble();
}

DeviceButton _button(Map<String, Object?> args) {
  final name = args['button'];
  final match = DeviceButton.values.where((b) => b.name == name).firstOrNull;
  if (match == null) {
    throw ArgumentError(
      'button must be one of ${DeviceButton.values.map((b) => b.name)}',
    );
  }
  return match;
}

/// Taps at the step's x,y or on its label's element; returns where.
Future<(double, double)> _tap(
  ToolContext c,
  Device device,
  DeviceSession session,
  Map<String, Object?> step,
) async {
  final (x, y) = switch (step['label']) {
    final String label => await _locate(
      c,
      device,
      label,
      step['timeout_ms'] as int? ?? 5000,
      step['index'] as int? ?? 0,
    ),
    _ => (_coord(step, 'x'), _coord(step, 'y')),
  };
  c.touch(session, TouchPhase.down, x, y);
  await Future<void>.delayed(const Duration(milliseconds: 60));
  c.touch(session, TouchPhase.up, x, y);
  return (x, y);
}

/// Center of the element [label] names, polling the accessibility tree
/// until it shows up (an app still launching, a screen animating in).
Future<(double, double)> _locate(
  ToolContext c,
  Device device,
  String label,
  int timeoutMs,
  int index,
) async {
  final clock = Stopwatch()..start();
  Object? lastError;
  while (true) {
    try {
      final match = findElement(
        await c.automation.elements(device),
        label,
        index: index,
      );
      if (match != null) return (match.centerX, match.centerY);
    } on UnsupportedError {
      rethrow;
    } catch (e) {
      lastError = e;
    }
    if (clock.elapsedMilliseconds >= timeoutMs) {
      throw StateError(
        'No element "$label" on ${device.name} after $timeoutMs ms'
        '${lastError == null ? '' : ': $lastError'}',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
}

/// Swipes per [args] (see the swipe tool); returns how many swipes ran.
Future<int> _swipe(
  ToolContext c,
  Device device,
  DeviceSession session,
  Map<String, Object?> args,
) async {
  final double x1, y1, x2, y2;
  if (args['label'] case final String label) {
    (x1, y1) = await _locate(
      c,
      device,
      label,
      args['timeout_ms'] as int? ?? 5000,
      args['index'] as int? ?? 0,
    );
    x2 = (x1 + ((args['dx'] as num?) ?? 0)).clamp(0.0, 1.0);
    y2 = (y1 + ((args['dy'] as num?) ?? 0)).clamp(0.0, 1.0);
  } else {
    [x1, y1, x2, y2] = [
      for (final k in ['x1', 'y1', 'x2', 'y2']) _coord(args, k),
    ];
  }
  final until = args['until'] as String?;
  final max = until == null ? 1 : args['max'] as int? ?? 20;
  for (var n = 0; n < max; n++) {
    if (until != null &&
        findElement(await c.automation.elements(device), until) != null) {
      return n;
    }
    await _drag(c, session, x1, y1, x2, y2, args['duration_ms'] as int?);
    // Let scrolling settle (a wheel snaps to an item) before looking again.
    if (until != null) await Future<void>.delayed(_settle);
  }
  if (until != null &&
      findElement(await c.automation.elements(device), until) == null) {
    throw StateError('No element "$until" on ${device.name} after $max swipes');
  }
  return max;
}

const _settle = Duration(milliseconds: 350);

Future<void> _drag(
  ToolContext c,
  DeviceSession session,
  double x1,
  double y1,
  double x2,
  double y2,
  int? durationMs,
) async {
  final duration = durationMs ?? 300;
  // Positions follow the clock, not a count of ~16 ms ticks, so a busy UI
  // isolate cannot stretch the swipe past duration_ms.
  final clock = Stopwatch()..start();
  c.touch(session, TouchPhase.down, x1, y1);
  while (clock.elapsedMilliseconds < duration) {
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final t = min(clock.elapsedMilliseconds / duration, 1.0);
    c.touch(session, TouchPhase.move, x1 + (x2 - x1) * t, y1 + (y2 - y1) * t);
  }
  c.touch(session, TouchPhase.up, x2, y2);
}

/// Checks a scenario step up front so a typo fails before any device moves.
void _validateStep(Map<String, Object?> step) {
  final repeat = step['repeat'];
  if (repeat != null && (repeat is! int || repeat < 1)) {
    throw ArgumentError('repeat must be an integer >= 1, got $repeat');
  }
  switch (step['action']) {
    case 'tap':
      final label = step['label'];
      if (label != null) {
        if (label is! String || label.trim().isEmpty) {
          throw ArgumentError('label must be a non-empty string');
        }
        for (final key in ['timeout_ms', 'index']) {
          final v = step[key];
          if (v != null && v is! int) {
            throw ArgumentError('$key must be an integer');
          }
        }
      } else {
        _coord(step, 'x');
        _coord(step, 'y');
      }
    case 'launch':
      if (![
        step['app'],
        step['android'],
        step['ios'],
      ].any((v) => v is String && v.isNotEmpty)) {
        throw ArgumentError('launch needs app (or android / ios)');
      }
    case 'type':
      if (step['text'] is! String) throw ArgumentError('type needs text');
    case 'swipe':
      final label = step['label'];
      if (label != null) {
        if (label is! String || label.trim().isEmpty) {
          throw ArgumentError('label must be a non-empty string');
        }
        if (step['dx'] is! num? || step['dy'] is! num?) {
          throw ArgumentError('dx and dy must be numbers');
        }
        if (step['dx'] == null && step['dy'] == null) {
          throw ArgumentError('swipe from a label needs dx or dy');
        }
      } else {
        for (final k in ['x1', 'y1', 'x2', 'y2']) {
          _coord(step, k);
        }
      }
      if (step['until'] is! String?) {
        throw ArgumentError('until must be a string');
      }
      final max = step['max'];
      if (max != null && (max is! int || max < 1)) {
        throw ArgumentError('max must be an integer >= 1');
      }
    case 'press':
      _button(step);
    case 'wait':
      if (step['ms'] is! int) throw ArgumentError('wait needs integer ms');
    default:
      throw ArgumentError(
        'Unknown action ${step['action']}; use tap, swipe, press, wait, '
        'launch or type',
      );
  }
}

Future<void> _runStep(
  ToolContext c,
  Device device,
  DeviceSession session,
  Map<String, Object?> step,
) => switch (step['action']) {
  'tap' => _tap(c, device, session, step),
  'swipe' => _swipe(c, device, session, step),
  'press' => Future.sync(() => session.press(_button(step))),
  'launch' => c.automation.launch(device, _appId(device, step)),
  'type' => c.automation.typeText(device, step['text']! as String),
  _ => Future<void>.delayed(Duration(milliseconds: step['ms']! as int)),
};

/// The launch step's app id for [device]'s platform.
String _appId(Device device, Map<String, Object?> step) {
  final id =
      step[device.os == DeviceOs.android ? 'android' : 'ios'] ?? step['app'];
  if (id is! String || id.isEmpty) {
    throw ArgumentError('launch has no app id for ${device.os.name}');
  }
  return id;
}
