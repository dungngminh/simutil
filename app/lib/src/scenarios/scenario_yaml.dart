import 'package:yaml/yaml.dart';

/// A scenario to start from in the editor.
const scenarioTemplate = '''
# Runs on every streamed device unless devices is set.
# devices: [iPhone 17 Pro, Pixel 8 Pro]
steps:
  - launch: com.example.app      # Android package / iOS bundle id
  - tap: Sign in                 # accessibility label, id or text
  - tap: [0.5, 0.8]              # or x, y in 0..1
  - type: hello@example.com
  - swipe: [0.5, 0.8, 0.5, 0.3]  # x1, y1, x2, y2
  - swipe: Settings              # from an element...
    dy: -0.3                     # ...by this much
    until: Privacy               # repeat until this shows up
  - press: back                  # back, home, recents, lock, volumeUp, volumeDown
  - wait: 500                    # ms
  - tap: Next
    repeat: 3
''';

const _actions = {'tap', 'swipe', 'press', 'wait', 'launch', 'type'};

/// `run_scenario` arguments from scenario YAML (see [scenarioTemplate]).
/// Each step names its action as a key (`tap: month`) or with
/// `action: tap` plus the tool's own fields. Throws [FormatException].
Map<String, Object?> scenarioFromYaml(String source) {
  final Object? doc;
  try {
    doc = _plain(loadYaml(source));
  } on YamlException catch (e) {
    throw FormatException(e.message, source, e.span?.start.offset);
  }
  final root = switch (doc) {
    final Map<String, Object?> m => m,
    final List<Object?> steps => {'steps': steps},
    _ => throw const FormatException('Expected steps: followed by a list'),
  };
  final steps = root['steps'];
  if (steps is! List || steps.isEmpty) {
    throw const FormatException('steps must be a non-empty list');
  }
  return {
    ...root,
    'steps': [
      for (final (i, s) in steps.indexed)
        if (s is Map<String, Object?>)
          _step(s, i)
        else
          throw FormatException('Step ${i + 1} must be a key: value map'),
    ],
  };
}

Map<String, Object?> _step(Map<String, Object?> step, int i) {
  if (step.containsKey('action')) return step;
  final keys = step.keys.where(_actions.contains).toList();
  if (keys.length != 1) {
    throw FormatException(
      'Step ${i + 1} needs exactly one of ${_actions.join(', ')}',
    );
  }
  final action = keys.single;
  final value = step[action];
  final rest = {...step}..remove(action);
  return {
    'action': action,
    ...rest,
    ...switch ((action, value)) {
      ('tap', [final x, final y]) => {'x': x, 'y': y},
      ('swipe', [final x1, final y1, final x2, final y2]) => {
        'x1': x1,
        'y1': y1,
        'x2': x2,
        'y2': y2,
      },
      ('tap' || 'swipe', final label?) => {'label': '$label'},
      ('press', final button) => {'button': button},
      ('wait', final ms) => {'ms': ms},
      ('type', final text) => {'text': '${text ?? ''}'},
      // launch: id, or launch: {android: ..., ios: ...}
      ('launch', final Map<String, Object?> ids) => ids,
      ('launch', final app) => {'app': '$app'},
      _ => const <String, Object?>{},
    },
  };
}

/// [YamlMap] / [YamlList] as plain maps and lists.
Object? _plain(Object? node) => switch (node) {
  final YamlMap m => {
    for (final MapEntry(:key, :value) in m.entries) '$key': _plain(value),
  },
  final YamlList l => [for (final v in l) _plain(v)],
  _ => node,
};
