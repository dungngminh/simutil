import 'dart:developer';
import 'dart:io';

import 'package:simutil/models/device.dart';
import 'package:simutil/models/plugin_config.dart';
import 'package:yaml/yaml.dart';

/// Loads and queries user-defined plugins from `~/.simutil/plugins.yaml`.
///
/// Plugins are shell commands grouped under a plugin identity. The registry
/// caches parsed [PluginConfig]s in memory after [load].
abstract class PluginRegistryService {
  /// Currently cached plugins. Empty until [load] completes.
  List<PluginConfig> get plugins;

  /// Reads and parses the plugins file, creating a default one if missing.
  Future<List<PluginConfig>> load();

  /// Re-reads the plugins file from disk, refreshing the cache.
  Future<List<PluginConfig>> reload();

  /// Plugins that expose at least one command runnable for [device].
  List<PluginConfig> pluginsForDevice(Device? device);

  /// Resolves a command bound to a command-level [shortcut] key.
  PluginCommandRef? commandByShortcut(String shortcut, Device? device);

  /// Resolves a plugin bound to a plugin-level [shortcut] key.
  PluginConfig? pluginByShortcut(String shortcut, Device? device);
}

class PluginRegistryServiceImpl implements PluginRegistryService {
  PluginRegistryServiceImpl({String? pluginsFilePath})
    : _pluginsFilePath = pluginsFilePath;

  final String? _pluginsFilePath;

  List<PluginConfig> _plugins = const [];

  @override
  List<PluginConfig> get plugins => _plugins;

  String get _pluginsPath {
    final override = _pluginsFilePath;
    if (override != null) return override;
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/.simutil/plugins.yaml';
  }

  @override
  Future<List<PluginConfig>> load() async {
    final file = File(_pluginsPath);
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      await file.writeAsString(_defaultPluginsYaml);
    }
    return _parseFile(file);
  }

  @override
  Future<List<PluginConfig>> reload() => _parseFile(File(_pluginsPath));

  Future<List<PluginConfig>> _parseFile(File file) async {
    try {
      if (!await file.exists()) {
        _plugins = const [];
        return _plugins;
      }
      final content = await file.readAsString();
      final doc = loadYaml(content);
      if (doc is! YamlMap) {
        _plugins = const [];
        return _plugins;
      }
      final rawPlugins = doc['plugins'];
      if (rawPlugins is! YamlList) {
        _plugins = const [];
        return _plugins;
      }
      final parsed = <PluginConfig>[];
      final seenIds = <String>{};
      for (final entry in rawPlugins) {
        if (entry is! Map) continue;
        try {
          final plugin = PluginConfig.fromMap(entry);
          if (!plugin.enabled) continue;
          if (!seenIds.add(plugin.id)) {
            log('Duplicate plugin id "${plugin.id}" ignored', name: 'plugins');
            continue;
          }
          parsed.add(plugin);
        } catch (e) {
          log('Skipping invalid plugin entry: $e', name: 'plugins');
        }
      }
      _plugins = parsed;
      return _plugins;
    } catch (e) {
      log('Failed to parse plugins.yaml: $e', name: 'plugins');
      _plugins = const [];
      return _plugins;
    }
  }

  @override
  List<PluginConfig> pluginsForDevice(Device? device) =>
      _plugins.where((plugin) => plugin.hasCommandsFor(device)).toList();

  @override
  PluginCommandRef? commandByShortcut(String shortcut, Device? device) {
    final key = shortcut.toLowerCase();
    for (final plugin in _plugins) {
      for (final command in plugin.commandsFor(device)) {
        if (command.shortcut == key) {
          return PluginCommandRef(plugin: plugin, command: command);
        }
      }
    }
    return null;
  }

  @override
  PluginConfig? pluginByShortcut(String shortcut, Device? device) {
    final key = shortcut.toLowerCase();
    for (final plugin in _plugins) {
      if (plugin.shortcut == key && plugin.hasCommandsFor(device)) {
        return plugin;
      }
    }
    return null;
  }
}

const _defaultPluginsYaml = '''
# Simutil Plugins
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
