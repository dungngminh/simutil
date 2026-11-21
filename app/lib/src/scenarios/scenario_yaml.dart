import 'package:simutil_core/simutil_core.dart';

/// A named flow the editor can load from the "Samples" menu, for [os].
typedef ScenarioSample = ({String name, DeviceOs os, String flow});

/// The flow the scenarios editor starts from (and resets to) for [os]: the
/// "Basic" sample. Runs on the chosen devices in parallel. See
/// https://docs.maestro.dev for the full command set.
String scenarioTemplate(DeviceOs os) =>
    scenarioSamples.firstWhere((s) => s.os == os).flow;

/// Ready-made flows shown in the editor's "Samples" menu, per platform. They
/// target the built-in Settings app (`com.android.settings` on Android,
/// `com.apple.Preferences` on iOS) so they run with no extra setup; swap the
/// `appId` and the on-screen labels for your own app. Labels are English.
const scenarioSamples = <ScenarioSample>[
  (name: 'Basic', os: DeviceOs.android, flow: _androidBasic),
  (name: 'Settings walkthrough', os: DeviceOs.android, flow: _androidWalk),
  (name: 'Search & input', os: DeviceOs.android, flow: _androidSearch),
  (name: 'Gestures', os: DeviceOs.android, flow: _androidGestures),
  (name: 'Basic', os: DeviceOs.ios, flow: _iosBasic),
  (name: 'Settings walkthrough', os: DeviceOs.ios, flow: _iosWalk),
  (name: 'Search & input', os: DeviceOs.ios, flow: _iosSearch),
  (name: 'Gestures', os: DeviceOs.ios, flow: _iosGestures),
  (name: 'Dark mode (Developer)', os: DeviceOs.ios, flow: _iosDarkMode),
];

// Comments stay short so they fit the panel without wrapping.

const _androidBasic = '''
# Maestro flow: runs on every
# selected device at once.
appId: com.android.settings
---
- launchApp
- assertVisible: "Settings"
# - tapOn: "Network & internet"
# - inputText: "hello@example.com"
# - swipe:
#     direction: UP
# - back
''';

const _androidWalk = '''
# Open a section, check it, go back.
appId: com.android.settings
---
- launchApp
- assertVisible: "Settings"
- tapOn: "Network & internet"
- assertVisible: "Internet"
- back
- assertVisible: "Settings"
''';

const _androidSearch = '''
# Type a query, then open a result.
appId: com.android.settings
---
- launchApp
- tapOn: "Search settings"
- inputText: "Battery"
- pressKey: Enter
- assertVisible: "Battery"
- hideKeyboard
- back
''';

const _androidGestures = '''
# Swipe, scroll to a row, long-press.
appId: com.android.settings
---
- launchApp
- swipe:
    direction: UP
- scrollUntilVisible:
    element:
      text: "About phone"
    direction: DOWN
- longPressOn: "About phone"
- assertVisible: "About phone"
- back
''';

const _iosBasic = '''
# Maestro flow: runs on every
# selected device at once.
appId: com.apple.Preferences
---
- launchApp
- assertVisible: "General"
# - tapOn: "General"
# - inputText: "hello@example.com"
# - swipe:
#     direction: UP
# - back
''';

const _iosWalk = '''
# Open a section, check it, go back.
appId: com.apple.Preferences
---
- launchApp:
    stopApp: true
- tapOn: "General"
- assertVisible: "About"
- tapOn:
    id: "BackButton"
- assertVisible: "Accessibility"
''';

const _iosSearch = '''
# Type into the search bar at the bottom.
appId: com.apple.Preferences
---
- launchApp:
    stopApp: true
- tapOn:
    point: "50%,94%"
- inputText: "Camera"
- assertVisible: "Camera"
''';

const _iosGestures = '''
# Swipe, scroll to a row, long-press.
appId: com.apple.Preferences
---
- launchApp:
    stopApp: true
- swipe:
    direction: UP
- scrollUntilVisible:
    element:
      text: "Privacy & Security"
    direction: DOWN
- longPressOn: "Privacy & Security"
- assertVisible: "Privacy & Security"
''';

const _iosDarkMode = '''
# Developer → turn on Dark Appearance.
appId: com.apple.Preferences
---
- launchApp:
    stopApp: true
- scrollUntilVisible:
    element: "Developer"
    direction: DOWN
- tapOn: "Developer"
- assertVisible: "Appearance"
# The switch reads "0" (off) or "1" (on);
# tap it only when off. A tap on the row
# does not flip an iOS switch.
- runFlow:
    when:
      visible:
        id: "UIAppearanceSettings"
        text: "0"
    commands:
      - tapOn:
          point: "86%,22%"
- assertVisible:
    id: "UIAppearanceSettings"
    text: "1"
''';

/// The 0-based line of each top-level command in a Maestro [flow]: the
/// unindented `- ` items after the `---` that ends the config section. The
/// Nth entry is the line of the step Maestro reports Nth.
List<int> flowStepLines(String flow) {
  final lines = flow.split('\n');
  final start = lines.indexWhere((l) => l.trimRight() == '---') + 1;
  return [
    for (var i = start; i < lines.length; i++)
      if (lines[i].startsWith('- ') || lines[i].trimRight() == '-') i,
  ];
}
