import 'dart:io';

import 'package:simutil_shared/src/app_settings.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_plugins/simutil_plugins.dart';
import 'package:yaml/yaml.dart';

/// Loads and persists user settings from `~/.simutil/settings.yaml`.
abstract interface class SettingsService {
  /// File-backed service; [settingsFilePath] defaults to
  /// [defaultSettingsPath]. [exec] opens the file in [openInEditor].
  factory SettingsService(CommandExec exec, {String? settingsFilePath}) =
      _FileSettingsService;

  /// Absolute path to the unified config file (`~/.simutil/settings.yaml`).
  String get configFilePath;

  /// Reads settings from disk, returning defaults when missing.
  Future<AppSettings> load();

  /// Persists [settings] to disk.
  Future<void> save(AppSettings settings);

  /// Applies [updater] and persists the result.
  Future<AppSettings> update(AppSettings Function(AppSettings) updater);

  /// Opens [configFilePath] in the OS default application.
  Future<void> openInEditor();
}

/// Function that transforms the current [AppSettings].
typedef SettingsUpdater = AppSettings Function(AppSettings);

/// Settings are stored at `~/.simutil/settings.yaml` alongside the `plugins:`
/// section in the same file.
final class _FileSettingsService implements SettingsService {
  _FileSettingsService(this._exec, {String? settingsFilePath})
    : _settingsFilePath = settingsFilePath;

  final CommandExec _exec;
  final String? _settingsFilePath;

  String get _settingsPath => _settingsFilePath ?? defaultSettingsPath();

  @override
  String get configFilePath => _settingsPath;

  @override
  Future<AppSettings> load() async {
    await _ensureSettings();
    return _parse(await File(_settingsPath).readAsString());
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _ensureSettings();
    final file = File(_settingsPath);
    final content = await file.readAsString();
    await file.writeAsString(
      mergeSettingsScalars(
        content,
        themeName: settings.themeName,
        lastSelectedDeviceId: settings.lastSelectedDeviceId,
      ),
    );
  }

  @override
  Future<AppSettings> update(SettingsUpdater updater) async {
    final current = await load();
    final updated = updater(current);
    await save(updated);
    return updated;
  }

  @override
  Future<void> openInEditor() async {
    await _ensureSettings();
    final path = _settingsPath;
    if (Platform.isMacOS) {
      await _exec.run('open', arguments: [path]);
    } else if (Platform.isWindows) {
      await _exec.run('cmd', arguments: ['/c', 'start', '', path]);
    } else {
      await _exec.run('xdg-open', arguments: [path]);
    }
  }

  /// Creates the file or inserts missing app keys, keeping existing values
  /// and any other content (such as the `plugins:` section).
  Future<void> _ensureSettings() async {
    final file = File(_settingsPath);
    await file.parent.create(recursive: true);
    final content = await file.exists() ? await file.readAsString() : '';
    if (_themeKey.hasMatch(content) && _deviceKey.hasMatch(content)) return;

    final current = _parse(content);
    await file.writeAsString(
      mergeSettingsScalars(
        content,
        themeName: current.themeName,
        lastSelectedDeviceId: current.lastSelectedDeviceId,
      ),
    );
  }

  AppSettings _parse(String content) {
    try {
      final yaml = loadYaml(content);
      if (yaml is! YamlMap) return const AppSettings();
      return _fromYaml(yaml);
    } catch (_) {
      return const AppSettings();
    }
  }

  AppSettings _fromYaml(YamlMap yaml) {
    final deviceId = yaml['last_selected_device_id'];
    return AppSettings(
      themeName: yaml['theme'] as String? ?? 'dark',
      lastSelectedDeviceId: deviceId == null || deviceId == '~'
          ? null
          : deviceId.toString(),
    );
  }
}

final _themeKey = RegExp(r'^theme:', multiLine: true);
final _deviceKey = RegExp(r'^last_selected_device_id:', multiLine: true);

const _settingsHeader = [
  '# Simutil configuration',
  '#',
  '# Press <e> in the app to open this file in your default editor.',
  '# Plugin changes apply after restart (or press <r> to refresh devices).',
  '',
];

/// Replaces or inserts `theme:` and `last_selected_device_id:` lines while
/// preserving the rest of the file (plugins, comments).
///
/// When both keys are missing they are prepended under the app header; when
/// one is missing it is inserted next to the other.
String mergeSettingsScalars(
  String content, {
  required String themeName,
  required String? lastSelectedDeviceId,
}) {
  final themeLine = 'theme: $themeName';
  final deviceLine = 'last_selected_device_id: ${lastSelectedDeviceId ?? '~'}';
  final lines = content.isEmpty ? <String>[] : content.split('\n');
  final themeAt = lines.indexWhere((l) => l.startsWith('theme:'));
  final deviceAt = lines.indexWhere(
    (l) => l.startsWith('last_selected_device_id:'),
  );

  if (themeAt >= 0) lines[themeAt] = themeLine;
  if (deviceAt >= 0) lines[deviceAt] = deviceLine;

  if (themeAt < 0 && deviceAt < 0) {
    final separator = lines.isEmpty ? [''] : ['', ''];
    return [
          ..._settingsHeader,
          themeLine,
          deviceLine,
          ...separator,
        ].join('\n') +
        lines.join('\n');
  }
  if (themeAt < 0) lines.insert(deviceAt, themeLine);
  if (deviceAt < 0) lines.insert(themeAt + 1, deviceLine);
  return lines.join('\n');
}
