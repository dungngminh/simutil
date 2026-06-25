import 'dart:developer';
import 'dart:io';

import 'package:simutil/models/device.dart';
import 'package:simutil/models/plugin_config.dart';
import 'package:simutil/services/user_config.dart';
import 'package:yaml/yaml.dart';

/// Loads and queries user-defined plugins from the `plugins:` section of
/// `~/.simutil/settings.yaml`.
///
/// Plugins are shell commands grouped under a plugin identity. The registry
/// caches parsed [PluginConfig]s in memory after [load].
abstract class PluginRegistryService {
  /// Currently cached plugins. Empty until [load] completes.
  List<PluginConfig> get plugins;

  /// Reads and parses the config file, creating a default one if missing.
  Future<List<PluginConfig>> load();

  /// Re-reads the config file from disk, refreshing the cache.
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
    : _configFilePath = pluginsFilePath;

  final String? _configFilePath;

  List<PluginConfig> _plugins = const [];

  @override
  List<PluginConfig> get plugins => _plugins;

  String get _configPath => resolveConfigPath(_configFilePath);

  @override
  Future<List<PluginConfig>> load() async {
    await ensureConfigFile(_configPath);
    return _parseFile(File(_configPath));
  }

  @override
  Future<List<PluginConfig>> reload() => _parseFile(File(_configPath));

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
      log('Failed to parse settings.yaml plugins: $e', name: 'plugins');
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
