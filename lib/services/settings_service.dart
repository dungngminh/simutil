import 'dart:io';

import 'package:simutil/models/app_settings.dart';
import 'package:simutil/services/command_exec.dart';
import 'package:simutil/services/user_config.dart';
import 'package:yaml/yaml.dart';

abstract class SettingsService {
  /// Absolute path to the unified config file (`~/.simutil/settings.yaml`).
  String get configFilePath;

  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
  Future<AppSettings> update(AppSettings Function(AppSettings) updater);

  /// Opens [configFilePath] in the OS default application.
  Future<void> openInEditor();
}

typedef SettingsUpdater = AppSettings Function(AppSettings);

/// Settings are stored at `~/.simutil/settings.yaml` alongside the `plugins:`
/// section in the same file.
class SettingsServiceImpl implements SettingsService {
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
