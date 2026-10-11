/// Scenario step actions, as YAML keys.
const scenarioActions = ['launch', 'tap', 'swipe', 'type', 'press', 'wait'];

/// Options a step can carry besides its action.
const scenarioOptions = [
  'repeat',
  'timeout_ms',
  'index',
  'dx',
  'dy',
  'until',
  'max',
  'duration_ms',
  'clear_state',
  'android',
  'ios',
];

const _topLevel = ['steps', 'devices'];
const _buttons = ['back', 'home', 'recents', 'lock', 'volumeUp', 'volumeDown'];

/// What to offer at the cursor: [start] is where the word being typed
/// begins (it is replaced on accept), each item's `insert` replaces it.
typedef ScenarioSuggestions = ({
  int start,
  List<({String label, String insert})> items,
});

/// Suggestions for the cursor at [offset] in [text]: actions after `- `,
/// step options on indented lines, keys at the top level, buttons after
/// `press:` and [devices] inside `devices: [...]`. Null when nothing fits.
ScenarioSuggestions? scenarioSuggestions(
  String text,
  int offset, {
  List<String> devices = const [],
}) {
  if (offset < 0 || offset > text.length) return null;
  final lineStart = text.lastIndexOf('\n', offset - 1) + 1;
  final before = text.substring(lineStart, offset);
  if (before.contains('#')) return null;

  ScenarioSuggestions? offer(
    String prefix,
    Iterable<String> words, {
    String suffix = '',
    bool allowEmpty = false,
  }) {
    if (prefix.isEmpty && !allowEmpty) return null;
    final p = prefix.toLowerCase();
    final items = [
      for (final w in words)
        if (w.toLowerCase().startsWith(p) && w != prefix)
          (label: w, insert: '$w$suffix'),
    ];
    if (items.isEmpty) return null;
    return (start: offset - prefix.length, items: items);
  }

  if (RegExp(r'^\s*-\s+(\w*)$').firstMatch(before) case final m?) {
    return offer(m[1]!, scenarioActions, suffix: ': ', allowEmpty: true);
  }
  if (RegExp(r'press:\s*(\w*)$').firstMatch(before) case final m?) {
    return offer(m[1]!, _buttons, allowEmpty: true);
  }
  if (RegExp(r'^\s*devices:\s*\[(?:[^\]]*,)?\s*([^,\]]*)$').firstMatch(before)
      case final m?) {
    return offer(m[1]!, devices, allowEmpty: true);
  }
  if (RegExp(r'^\s+(\w+)$').firstMatch(before) case final m?) {
    return offer(m[1]!, scenarioOptions, suffix: ': ');
  }
  if (RegExp(r'^(\w+)$').firstMatch(before) case final m?) {
    return offer(m[1]!, _topLevel, suffix: ':');
  }
  return null;
}
