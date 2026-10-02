import 'dart:io';

/// Default path of the shared SimUtil config file (`~/.simutil/settings.yaml`).
///
/// The file is shared with the app, which owns its own keys; this package only
/// reads and seeds the `plugins:` section.
String defaultSettingsPath() {
  final env = Platform.environment;
  final home = env['HOME'] ?? env['USERPROFILE'] ?? '.';
  return '$home/.simutil/settings.yaml';
}

/// Default `plugins:` section (with its comment block) seeded into the config.
const String defaultPluginsYaml = '''
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

final _pluginsKey = RegExp(r'^plugins:', multiLine: true);

/// Appends [defaultPluginsYaml] to [path] when the file has no top-level
/// `plugins:` key, creating the file if needed. Other content is untouched.
///
/// Users who want no plugins should keep `plugins: []` rather than deleting
/// the key, or the default section comes back.
Future<void> ensurePluginsSection(String path) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  final content = await file.exists() ? await file.readAsString() : '';
  if (_pluginsKey.hasMatch(content)) return;

  final separator = content.isEmpty || content.endsWith('\n\n')
      ? ''
      : content.endsWith('\n')
      ? '\n'
      : '\n\n';
  await file.writeAsString('$content$separator$defaultPluginsYaml');
}
