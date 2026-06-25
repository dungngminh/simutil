import 'dart:io';

/// Resolves the path to the unified user config file.
String resolveConfigPath(String? override) {
  if (override != null) return override;
  final home = Platform.environment['HOME'] ?? '.';
  return '$home/.simutil/settings.yaml';
}

/// Default unified config: settings scalars + scrcpy plugin.
const String defaultConfigYaml = '''
# Simutil configuration
#
# Press <e> in the app to open this file in your default editor.
# Plugin changes apply after restart (or press <r> to refresh devices).

theme: dark
last_selected_device_id: ~

# Plugins
#
# Define external shell-command plugins here. Each plugin groups one or more
# commands. In the app press <p> on a selected device to pick a plugin and then
# a command to run. You can also give a command a "shortcut" to run it directly.
#
# Template variables available in "args":
#   {device.id}, {device.name}, {device.platform}, {device.os}, {device.state}
#
# Command fields:
#   id, label            (required) identity shown in the menu
#   command              (required) executable to run
#   args                 (optional) list of arguments, supports templates
#   description          (optional) help text shown under the label
#   platforms            (optional) [android, ios] filter; empty = any
#   requires_running     (optional) only show when the device is running
#   mode                 (optional) detached (default) | inherit
#   shortcut             (optional) single key to run this command directly

plugins:
  - id: scrcpy
    label: scrcpy
    description: Screen mirroring and control for Android
    availability:
      command: scrcpy
      args: [--version]
    commands:
      - id: mirror
        label: Screen Mirror
        description: Mirror the device screen
        command: scrcpy
        args: [-s, "{device.id}"]
        platforms: [android]
        requires_running: true
        mode: detached
        shortcut: s
      - id: mirror-no-audio
        label: Screen Mirror (No Audio)
        description: Mirror without forwarding audio
        command: scrcpy
        args: [-s, "{device.id}", --no-audio]
        platforms: [android]
        requires_running: true
        mode: detached
''';

/// Ensures [configPath] exists with settings + plugins sections.
Future<void> ensureConfigFile(String configPath) async {
  final file = File(configPath);
  await file.parent.create(recursive: true);
  if (!await file.exists()) {
    await file.writeAsString(defaultConfigYaml);
  }
}

/// Replaces or inserts `theme:` and `last_selected_device_id:` lines while
/// preserving the rest of the file (plugins, comments).
String mergeSettingsScalars(
  String content, {
  required String themeName,
  required String? lastSelectedDeviceId,
}) {
  final deviceValue = lastSelectedDeviceId ?? '~';
  final lines = content.split('\n');
  var themeReplaced = false;
  var deviceReplaced = false;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.startsWith('theme:')) {
      lines[i] = 'theme: $themeName';
      themeReplaced = true;
    } else if (line.startsWith('last_selected_device_id:')) {
      lines[i] = 'last_selected_device_id: $deviceValue';
      deviceReplaced = true;
    }
  }

  if (themeReplaced && deviceReplaced) {
    return lines.join('\n');
  }

  final insertAt = _insertIndexAfterHeader(lines);
  final toInsert = <String>[];
  if (!themeReplaced) toInsert.add('theme: $themeName');
  if (!deviceReplaced) {
    toInsert.add('last_selected_device_id: $deviceValue');
  }
  lines.insertAll(insertAt, toInsert);
  return lines.join('\n');
}

int _insertIndexAfterHeader(List<String> lines) {
  var i = 0;
  while (i < lines.length &&
      (lines[i].trim().isEmpty || lines[i].trimLeft().startsWith('#'))) {
    i++;
  }
  return i;
}
