import 'dart:io';

import 'package:simutil/models/app_settings.dart';
import 'package:yaml/yaml.dart';

abstract class SettingsService {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
  Future<AppSettings> update(AppSettings Function(AppSettings) updater);
}

typedef SettingsUpdater = AppSettings Function(AppSettings);

/// Settings are stored at `~/.simutil/settings.yaml`.
class SettingsServiceImpl implements SettingsService {
  const SettingsServiceImpl();

  static String get _settingsPath {
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/.simutil/settings.yaml';
  }

  @override
  Future<AppSettings> load() async {
    final file = File(_settingsPath);
    final dir = file.parent;
    if (!await file.exists()) {
      await dir.create(recursive: true);
      const defaults = AppSettings();
      await file.writeAsString(_toYaml(defaults));
      return defaults;
    }
    try {
      final content = await file.readAsString();
      final yaml = loadYaml(content) as YamlMap;
      return _fromYaml(yaml);
    } catch (_) {
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    final file = File(_settingsPath);
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await file.writeAsString(_toYaml(settings));
  }

  @override
  Future<AppSettings> update(SettingsUpdater updater) async {
    final current = await load();
    final updated = updater(current);
    await save(updated);
    return updated;
  }

  AppSettings _fromYaml(YamlMap yaml) {
    return AppSettings(
      themeName: yaml['theme'] as String? ?? 'dark',
      lastSelectedDeviceId: yaml['last_selected_device_id'] as String?,
    );
  }

  String _toYaml(AppSettings settings) {
    final buf = StringBuffer()
      ..writeln('# Simutil Settings')
      ..writeln()
      ..writeln('theme: ${settings.themeName}')
      ..writeln(
        'last_selected_device_id: ${settings.lastSelectedDeviceId ?? "~"}',
      );
    return buf.toString();
  }
}
