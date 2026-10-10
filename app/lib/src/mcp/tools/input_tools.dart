import 'dart:async';

import 'package:simutil_app/src/mcp/mcp_server.dart';
import 'package:simutil_app/src/mcp/tools/tool_context.dart';
import 'package:simutil_core/simutil_core.dart';

/// Touch and button input, alone or as a scenario across devices.
List<McpTool> inputTools(ToolContext c) => [
  McpTool(
    name: 'tap',
    description: 'Tap at x,y normalized to 0..1 of the screen.',
    properties: {...deviceArg, 'x': point, 'y': point},
    required: ['device', 'x', 'y'],
    handler: (args) async {
      final x = _coord(args, 'x');
      final y = _coord(args, 'y');
      await _tap(await c.input(c.find(args)), x, y);
      return c.text('Tapped ($x, $y)');
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
      _validateStep({...args, 'action': 'swipe'});
      await _swipe(await c.input(c.find(args)), args);
      return c.text('Swiped');
    },
  ),
  McpTool(
    name: 'press_button',
    description: 'Press back (Android), home, recents or lock.',
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
        'Each device runs the steps in order; devices run in parallel. '
        'Steps: {action: tap, x, y} | {action: swipe, x1, y1, x2, y2, '
        'duration_ms?} | {action: press, button} | {action: wait, ms}. '
        "Coordinates are normalized 0..1. Returns each device's outcome.",
    properties: {
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
              'enum': ['tap', 'swipe', 'press', 'wait'],
            },
            'x': point,
            'y': point,
            'x1': point,
            'y1': point,
            'x2': point,
            'y2': point,
            'duration_ms': {'type': 'integer'},
            'button': _buttonSchema,
            'ms': {'type': 'integer'},
          },
          'required': ['action'],
        },
      },
    },
    required: ['steps'],
    handler: (args) async {
      final steps = [
        for (final s in args['steps']! as List)
          (s as Map).cast<String, Object?>(),
      ]..forEach(_validateStep);
      final targets = args['devices'] == null
          ? [for (final e in c.streams.stateValue.entries) e.device]
          : [
              for (final id in args['devices']! as List) c.find({'device': id}),
            ];
      if (targets.isEmpty) {
        throw ArgumentError('No devices: pass devices or stream some first');
      }
      final results = await Future.wait([
        for (final device in targets) _runScenario(c, device, steps),
      ]);
      return c.text(results);
    },
  ),
];

final _buttonSchema = {
  'type': 'string',
  'enum': [for (final b in DeviceButton.values) b.name],
};

/// Runs [steps] on [device]; reports where it stopped instead of throwing.
Future<Map<String, Object?>> _runScenario(
  ToolContext c,
  Device device,
  List<Map<String, Object?>> steps,
) async {
  final clock = Stopwatch()..start();
  var done = 0;
  try {
    final session = await c.input(device);
    for (final step in steps) {
      await _runStep(session, step);
      done++;
    }
    return {'device': device.name, 'ok': true, 'ms': clock.elapsedMilliseconds};
  } catch (e) {
    return {
      'device': device.name,
      'ok': false,
      'failed_step': done,
      'error': '$e',
    };
  }
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

Future<void> _tap(DeviceSession session, double x, double y) async {
  session.touch(TouchPhase.down, x, y);
  await Future<void>.delayed(const Duration(milliseconds: 60));
  session.touch(TouchPhase.up, x, y);
}

Future<void> _swipe(DeviceSession session, Map<String, Object?> args) async {
  final [x1, y1, x2, y2] = [
    for (final k in ['x1', 'y1', 'x2', 'y2']) _coord(args, k),
  ];
  final steps = ((args['duration_ms'] as int? ?? 300) / 16).ceil();
  session.touch(TouchPhase.down, x1, y1);
  for (var i = 1; i <= steps; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final t = i / steps;
    session.touch(TouchPhase.move, x1 + (x2 - x1) * t, y1 + (y2 - y1) * t);
  }
  session.touch(TouchPhase.up, x2, y2);
}

/// Checks a scenario step up front so a typo fails before any device moves.
void _validateStep(Map<String, Object?> step) {
  switch (step['action']) {
    case 'tap':
      _coord(step, 'x');
      _coord(step, 'y');
    case 'swipe':
      for (final k in ['x1', 'y1', 'x2', 'y2']) {
        _coord(step, k);
      }
    case 'press':
      _button(step);
    case 'wait':
      if (step['ms'] is! int) throw ArgumentError('wait needs integer ms');
    default:
      throw ArgumentError(
        'Unknown action ${step['action']}; use tap, swipe, press or wait',
      );
  }
}

Future<void> _runStep(DeviceSession session, Map<String, Object?> step) =>
    switch (step['action']) {
      'tap' => _tap(session, _coord(step, 'x'), _coord(step, 'y')),
      'swipe' => _swipe(session, step),
      'press' => Future.sync(() => session.press(_button(step))),
      _ => Future<void>.delayed(Duration(milliseconds: step['ms']! as int)),
    };
