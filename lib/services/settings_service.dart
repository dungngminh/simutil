import 'dart:io';

import 'package:simutil/models/app_settings.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:yaml/yaml.dart';

/// Loads and persists user settings from `~/.simutil/settings.yaml`.
abstract class SettingsService {
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
class SettingsServiceImpl implements SettingsService {
  /// Creates a service using [exec] and optional settings file path.
  SettingsServiceImpl(this._exec, {String? settingsFilePath})
    : _settingsFilePath = settingsFilePath;

  final CommandExec _exec;
  final String? _settingsFilePath;

  String get _settingsPath => resolveConfigPath(_settingsFilePath);

  @override
  String get configFilePath => _settingsPath;

  @override
  Future<AppSettings> load() async {
    await ensureConfigFile(_settingsPath);
    final file = File(_settingsPath);
    try {
      final content = await file.readAsString();
      final yaml = loadYaml(content);
      if (yaml is! YamlMap) return const AppSettings();
      return _fromYaml(yaml);
    } catch (_) {
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    await ensureConfigFile(_settingsPath);
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
    await ensureConfigFile(_settingsPath);
    final path = _settingsPath;
    if (Platform.isMacOS) {
      await _exec.run('open', arguments: [path]);
    } else if (Platform.isWindows) {
      await _exec.run('cmd', arguments: ['/c', 'start', '', path]);
    } else {
      await _exec.run('xdg-open', arguments: [path]);
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
