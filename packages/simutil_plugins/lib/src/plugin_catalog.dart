import 'dart:io';

import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_plugins/src/models/plugin_config.dart';
import 'package:simutil_plugins/src/settings_file.dart';
import 'package:yaml/yaml.dart';

/// Immutable set of enabled plugins parsed from the `plugins:` section of
/// `~/.simutil/settings.yaml`.
///
/// Obtain one with [loadPluginCatalog], or build it directly in tests.
final class PluginCatalog {
  /// Creates a catalog from already parsed [plugins].
  const PluginCatalog(this.plugins, {this.warnings = const []});

  /// Parses the `plugins:` section of a settings [yaml] document.
  ///
  /// Never throws: malformed YAML, invalid entries, and duplicate ids are
  /// skipped and described in [warnings]. Disabled plugins are dropped.
  factory PluginCatalog.parse(String yaml) {
    final Object? doc;
    try {
      doc = loadYaml(yaml);
    } on YamlException catch (e) {
      return PluginCatalog(const [], warnings: ['Invalid YAML: ${e.message}']);
    }
    final rawPlugins = doc is YamlMap ? doc['plugins'] : null;
    if (rawPlugins is! YamlList) return const PluginCatalog([]);

    final plugins = <PluginConfig>[];
    final warnings = <String>[];
    final seenIds = <String>{};
    for (final entry in rawPlugins) {
      if (entry is! Map) {
        warnings.add('Skipping plugin entry that is not a map: $entry');
        continue;
      }
      try {
        final plugin = PluginConfig.fromMap(entry);
        if (!plugin.enabled) continue;
        if (!seenIds.add(plugin.id)) {
          warnings.add('Duplicate plugin id "${plugin.id}" ignored');
          continue;
        }
        plugins.add(plugin);
      } catch (e) {
        warnings.add('Skipping invalid plugin entry: $e');
      }
    }
    return PluginCatalog(
      List.unmodifiable(plugins),
      warnings: List.unmodifiable(warnings),
    );
  }

  /// Enabled plugins in file order.
  final List<PluginConfig> plugins;

  /// Problems found while parsing, for showing to the user.
  final List<String> warnings;

  /// Plugins that expose at least one command runnable for [device].
  List<PluginConfig> forDevice(Device? device) =>
      plugins.where((plugin) => plugin.hasCommandsFor(device)).toList();

  /// Resolves a command bound to a command-level [shortcut] key.
  PluginCommandRef? commandByShortcut(String shortcut, Device? device) {
    final key = shortcut.toLowerCase();
    for (final plugin in plugins) {
      for (final command in plugin.commandsFor(device)) {
        if (command.shortcut == key) {
          return PluginCommandRef(plugin: plugin, command: command);
        }
      }
    }
    return null;
  }

  /// Resolves a plugin bound to a plugin-level [shortcut] key.
  PluginConfig? pluginByShortcut(String shortcut, Device? device) {
    final key = shortcut.toLowerCase();
    for (final plugin in plugins) {
      if (plugin.shortcut == key && plugin.hasCommandsFor(device)) {
        return plugin;
      }
    }
    return null;
  }

  /// Plugin with [pluginId], or `null`.
  PluginConfig? plugin(String pluginId) {
    for (final plugin in plugins) {
      if (plugin.id == pluginId) return plugin;
    }
    return null;
  }

  /// Command [commandId] of plugin [pluginId], or `null` when either is
  /// unknown.
  PluginCommandRef? command(String pluginId, String commandId) {
    final owner = plugin(pluginId);
    if (owner == null) return null;
    for (final command in owner.commands) {
      if (command.id == commandId) {
        return PluginCommandRef(plugin: owner, command: command);
      }
    }
    return null;
  }
}

/// Loads a [PluginCatalog]; [loadPluginCatalog] is the default. Inject a
/// different loader to feed a fixed catalog in tests.
typedef PluginCatalogLoader = Future<PluginCatalog> Function();

/// Reads [path] (default [defaultSettingsPath]) into a [PluginCatalog],
/// seeding the default `plugins:` section first when it is missing.
Future<PluginCatalog> loadPluginCatalog({String? path}) async {
  final file = path ?? defaultSettingsPath();
  try {
    await ensurePluginsSection(file);
    return PluginCatalog.parse(await File(file).readAsString());
  } on FileSystemException catch (e) {
    return PluginCatalog(const [], warnings: ['Cannot read $file: $e']);
  }
}
