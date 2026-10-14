/// A Maestro flow to start from in the scenarios editor. Runs on the chosen
/// devices in parallel. See https://docs.maestro.dev for the full command set.
const scenarioTemplate = '''
# Maestro flow — runs on the selected devices at the same time.
appId: com.android.settings      # Android package / iOS bundle id
---
- launchApp
- assertVisible: "Settings"
# - tapOn: "General"
# - inputText: "hello@example.com"
# - swipe:
#     direction: UP
# - assertNotVisible: "Camera"
# - back
''';

/// A named flow the editor can load from the "Samples" menu.
typedef ScenarioSample = ({String name, String flow});

/// Ready-made flows shown in the editor's "Samples" menu. They target the
/// Android Settings app (`com.android.settings`) so they run with no extra
/// setup; swap the `appId` and the on-screen labels for your own app. The
/// first entry is the same as [scenarioTemplate].
const scenarioSamples = <ScenarioSample>[
  (name: 'Basic', flow: scenarioTemplate),
  (name: 'Settings walkthrough', flow: _walkthroughSample),
  (name: 'Search & input', flow: _searchSample),
  (name: 'Gestures', flow: _gesturesSample),
];

/// Opens a section, checks it, and goes back — tapOn / assertVisible / back.
const _walkthroughSample = '''
# Settings walkthrough — open a section, check it, then go back.
# Labels are from English Android Settings; change them for your app.
appId: com.android.settings
---
- launchApp
- assertVisible: "Settings"
- tapOn: "Network & internet"
- assertVisible: "Internet"
- back
- assertVisible: "Settings"
''';

/// Types into the search bar and opens a result — inputText / pressKey.
const _searchSample = '''
# Search & text input — type a query, then open a result.
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

/// Swipes, scrolls until a row shows, long-presses it — gesture commands.
const _gesturesSample = '''
# Gestures — swipe, scroll until a row is visible, then long-press it.
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
