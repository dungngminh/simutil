import 'dart:io';

import 'package:yaml/yaml.dart';

import '../models/app_settings.dart';
import '../models/launch_options.dart';

/// Service for loading and saving app settings as YAML.
///
/// Settings are stored at `~/.simutil/settings.yaml`.
class SettingsService {
  static String get _settingsPath {
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/.simutil/settings.yaml';
  }

  /// Load settings from disk. Returns defaults if file missing or corrupt.
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
      // If the file is corrupt, return defaults.
      return const AppSettings();
    }
  }

  /// Save settings to disk as YAML.
  Future<void> save(AppSettings settings) async {
    final file = File(_settingsPath);
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await file.writeAsString(_toYaml(settings));
  }

  /// Convenience: load → mutate → save.
  Future<AppSettings> update(AppSettings Function(AppSettings) updater) async {
    final current = await load();
    final updated = updater(current);
    await save(updated);
    return updated;
  }

  // ─── YAML Serialization ────────────────────────────────────────

  AppSettings _fromYaml(YamlMap yaml) {
    LaunchOptions options = const LaunchOptions();

    final launchMap = yaml['default_launch_options'];
    if (launchMap is YamlMap) {
      options = LaunchOptions(
        noAudio: launchMap['no_audio'] as bool? ?? false,
        wipeData: launchMap['wipe_data'] as bool? ?? false,
        gpu: launchMap['gpu'] as String? ?? 'auto',
        noSnapshot: launchMap['no_snapshot'] as bool? ?? false,
      );
    }

    return AppSettings(
      themeName: yaml['theme'] as String? ?? 'dark',
      defaultLaunchOptions: options,
      lastSelectedDeviceId: yaml['last_selected_device_id'] as String?,
    );
  }

  String _toYaml(AppSettings settings) {
    final buf = StringBuffer();
    buf.writeln('# SimUtil Settings');
    buf.writeln();
    buf.writeln('theme: ${settings.themeName}');
    buf.writeln(
      'last_selected_device_id: ${settings.lastSelectedDeviceId ?? "~"}',
    );
    buf.writeln();
    buf.writeln('default_launch_options:');
    buf.writeln('  no_audio: ${settings.defaultLaunchOptions.noAudio}');
    buf.writeln('  wipe_data: ${settings.defaultLaunchOptions.wipeData}');
    buf.writeln('  gpu: ${settings.defaultLaunchOptions.gpu}');
    buf.writeln('  no_snapshot: ${settings.defaultLaunchOptions.noSnapshot}');
    return buf.toString();
  }
}
