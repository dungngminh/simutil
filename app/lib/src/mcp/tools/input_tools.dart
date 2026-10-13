import 'dart:math';

import 'package:simutil_app/src/di.dart';
import 'package:simutil_app/src/mcp/mcp_server.dart';
import 'package:simutil_app/src/mcp/tools/tool_context.dart';
import 'package:simutil_apple/simutil_apple.dart';
import 'package:simutil_core/simutil_core.dart';

/// Ad-hoc, single-device input: touch, buttons, text, app launch and
/// accessibility lookup. Whole test flows run through Maestro (run_maestro).
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
      final device = c.find(args);
      final (x, y, native) = await _tap(c, device, await c.input(device), args);
      return c.text(
        native ? 'Pressed natively at ($x, $y)' : 'Tapped ($x, $y)',
      );
    },
  ),
  McpTool(
    name: 'install_app',
    description:
        'Install an app from a file on this computer, replacing an installed '
        'copy: an .apk on Android, a simulator .app bundle or .ipa on iOS. '
        'convert_for_simulator installs an iPhone (device) build on an iOS '
        'simulator by converting a copy (Apple Silicon, unencrypted apps; '
        'keychain, app groups and push may not work).',
    properties: {
      ...deviceArg,
      'path': {'type': 'string'},
      'convert_for_simulator': {'type': 'boolean', 'default': false},
    },
    required: ['device', 'path'],
    handler: (args) async {
      final path = args['path'];
      if (path is! String || path.isEmpty) throw ArgumentError('path required');
      final device = c.find(args);
      if (args['convert_for_simulator'] == true) {
        if (device.os != DeviceOs.ios || device.type.isPhysical) {
          throw ArgumentError('convert_for_simulator needs an iOS simulator');
        }
        await getIt<IosAutomation>().installForSimulator(device, path);
        return c.text('Converted and installed $path');
      }
      try {
        await c.automation.install(device, path);
      } on DeviceOnlyBuildException catch (e) {
        throw StateError(
          '${e.message} Retry with convert_for_simulator: true to convert it.',
        );
      }
      return c.text('Installed $path');
    },
  ),
  McpTool(
    name: 'launch_app',
    description:
        'Launch an app by Android package name or iOS bundle id '
        '(e.g. com.example.app), stopping it first if it runs; clear_state '
        'also wipes its data (simulators and Android).',
    properties: {
      ...deviceArg,
      'app': {'type': 'string'},
      'clear_state': {'type': 'boolean', 'default': false},
    },
    required: ['device', 'app'],
    handler: (args) async {
      final app = args['app'];
      if (app is! String || app.isEmpty) throw ArgumentError('app required');
      final clear = args['clear_state'] == true;
      await c.automation.launch(c.find(args), app, clearState: clear);
      return c.text(
        clear ? 'Launched $app with a clean state' : 'Launched $app',
      );
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
      final text = args['text'];
      if (text is! String) throw ArgumentError('text required');
      final device = c.find(args);
      await c.input(device);
      await c.automation.typeText(device, text);
      return c.text('Typed');
    },
  ),
  McpTool(
    name: 'find_elements',
    description:
        "Elements on screen from the device's accessibility tree: label, "
        'id, value, role, center x/y and frame [left, top, right, bottom], '
        'all normalized 0..1. Pass label to keep only matching ones (also by '
        'id; unfiltered, id-only elements are left out).',
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
        'swipe (up to max times) until an element matching until shows up.',
    properties: {...deviceArg, ..._swipeArgs, ..._labelArgs},
    required: ['device'],
    handler: (args) async {
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
];

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

/// Taps at [args]'s x,y or on its label's element; returns where, and whether
/// the platform tapped the element natively.
Future<(double, double, bool)> _tap(
  ToolContext c,
  Device device,
  DeviceSession session,
  Map<String, Object?> args,
) async {
  if (args['label'] case final String label) {
    final element = await _locate(
      c,
      device,
      label,
      args['timeout_ms'] as int? ?? 5000,
      args['index'] as int? ?? 0,
    );
    final (x, y) = (element.centerX, element.centerY);
    if (await c.automation.tapElement(device, element)) {
      c.marks?.add(session.deviceId, TouchPhase.down, x, y);
      c.marks?.add(session.deviceId, TouchPhase.up, x, y);
      return (x, y, true);
    }
    final (tx, ty) = await _touchAt(c, session, x, y);
    return (tx, ty, false);
  }
  final (tx, ty) = await _touchAt(
    c,
    session,
    _coord(args, 'x'),
    _coord(args, 'y'),
  );
  return (tx, ty, false);
}

Future<(double, double)> _touchAt(
  ToolContext c,
  DeviceSession session,
  double x,
  double y,
) async {
  c.touch(session, TouchPhase.down, x, y);
  await Future<void>.delayed(const Duration(milliseconds: 60));
  c.touch(session, TouchPhase.up, x, y);
  return (x, y);
}

/// The element [label] names, polling the accessibility tree until it shows up.
Future<UiElement> _locate(
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
      if (match != null) return match;
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
    final from = await _locate(
      c,
      device,
      label,
      args['timeout_ms'] as int? ?? 5000,
      args['index'] as int? ?? 0,
    );
    (x1, y1) = (from.centerX, from.centerY);
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
  final clock = Stopwatch()..start();
  c.touch(session, TouchPhase.down, x1, y1);
  while (clock.elapsedMilliseconds < duration) {
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final t = min(clock.elapsedMilliseconds / duration, 1.0);
    c.touch(session, TouchPhase.move, x1 + (x2 - x1) * t, y1 + (y2 - y1) * t);
  }
  c.touch(session, TouchPhase.up, x2, y2);
}
