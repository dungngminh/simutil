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
