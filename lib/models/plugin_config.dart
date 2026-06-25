import 'package:simutil/models/device.dart';
import 'package:simutil/models/device_os.dart';

/// How a plugin command's process is started.
enum PluginRunMode {
  /// The process runs independently of simutil (e.g. GUI tools like scrcpy).
  detached,

  /// The process shares stdio with simutil (blocking CLI tools).
  inherit;

  static PluginRunMode fromString(String? raw) {
    return switch (raw?.toLowerCase()) {
      'inherit' => PluginRunMode.inherit,
      _ => PluginRunMode.detached,
    };
  }
}

/// Optional availability probe used to check whether a tool is installed.
///
/// Defaults to running `<command> --version` when no explicit args are given.
class PluginAvailabilityCheck {
  const PluginAvailabilityCheck({
    required this.command,
    this.args = const ['--version'],
  });

  factory PluginAvailabilityCheck.fromMap(Map<dynamic, dynamic> map) {
    final command = map['command'];
    if (command is! String || command.trim().isEmpty) {
      throw const FormatException('availability.command is required');
    }
    final rawArgs = map['args'];
    return PluginAvailabilityCheck(
      command: command,
      args: rawArgs == null ? const ['--version'] : _stringList(rawArgs),
    );
  }

  final String command;
  final List<String> args;
}

/// A single runnable command that belongs to a [PluginConfig].
class PluginCommandConfig {
  const PluginCommandConfig({
    required this.id,
    required this.label,
    required this.command,
    this.description,
    this.args = const [],
    this.platforms = const [],
    this.requiresRunning = false,
    this.mode = PluginRunMode.detached,
    this.shortcut,
    this.availability,
  });

  factory PluginCommandConfig.fromMap(Map<dynamic, dynamic> map) {
    final availability = map['availability'];
    return PluginCommandConfig(
      id: _requiredString(map, 'id'),
      label: _requiredString(map, 'label'),
      command: _requiredString(map, 'command'),
      description: _optionalString(map, 'description'),
      args: _stringList(map['args']),
      platforms: _parsePlatforms(map['platforms']),
      requiresRunning: map['requires_running'] == true,
      mode: PluginRunMode.fromString(_optionalString(map, 'mode')),
      shortcut: _parseShortcut(map['shortcut']),
      availability: availability is Map
          ? PluginAvailabilityCheck.fromMap(availability)
          : null,
    );
  }

  final String id;
  final String label;
  final String command;
  final String? description;
  final List<String> args;
  final List<DeviceOs> platforms;
  final bool requiresRunning;
  final PluginRunMode mode;
  final String? shortcut;
  final PluginAvailabilityCheck? availability;

  /// Whether this command can run against [device] given its platform and
  /// running-state constraints.
  bool matches(Device? device) {
    if (platforms.isNotEmpty) {
      if (device == null || !platforms.contains(device.os)) return false;
    }
    if (requiresRunning && (device == null || !device.isRunning)) {
      return false;
    }
    return true;
  }

  /// Resolves [args] by interpolating `{device.*}` template variables.
  List<String> resolveArgs(Device? device) =>
      args.map((arg) => _interpolate(arg, device)).toList();
}

/// A plugin loaded from the `plugins:` section of `~/.simutil/settings.yaml`.
/// [commands] under a shared identity and availability probe.
class PluginConfig {
  const PluginConfig({
    required this.id,
    required this.label,
    required this.commands,
    this.description,
    this.enabled = true,
    this.availability,
    this.shortcut,
  });

  factory PluginConfig.fromMap(Map<dynamic, dynamic> map) {
    final rawCommands = map['commands'];
    if (rawCommands is! List || rawCommands.isEmpty) {
      throw const FormatException(
        'plugin requires a non-empty "commands" list',
      );
    }
    final commands = rawCommands
        .whereType<Map>()
        .map(PluginCommandConfig.fromMap)
        .toList();
    if (commands.isEmpty) {
      throw const FormatException('plugin has no valid commands');
    }
    final availability = map['availability'];
    return PluginConfig(
      id: _requiredString(map, 'id'),
      label: _requiredString(map, 'label'),
      commands: commands,
      description: _optionalString(map, 'description'),
      enabled: map['enabled'] != false,
      availability: availability is Map
          ? PluginAvailabilityCheck.fromMap(availability)
          : null,
      shortcut: _parseShortcut(map['shortcut']),
    );
  }

  final String id;
  final String label;
  final List<PluginCommandConfig> commands;
  final String? description;
  final bool enabled;
  final PluginAvailabilityCheck? availability;
  final String? shortcut;

  /// Commands available for [device] after platform/running filtering.
  List<PluginCommandConfig> commandsFor(Device? device) =>
      commands.where((command) => command.matches(device)).toList();

  /// Whether at least one command is available for [device].
  bool hasCommandsFor(Device? device) =>
      commands.any((command) => command.matches(device));
}

/// Pairs a [PluginConfig] with one of its [PluginCommandConfig]s, used when a
/// command is resolved via shortcut or after a two-step selection.
class PluginCommandRef {
  const PluginCommandRef({required this.plugin, required this.command});

  final PluginConfig plugin;
  final PluginCommandConfig command;
}

String _interpolate(String template, Device? device) {
  if (device == null) return template;
  return template
      .replaceAll('{device.id}', device.id)
      .replaceAll('{device.name}', device.name)
      .replaceAll('{device.platform}', device.platform)
      .replaceAll('{device.os}', device.os.name)
      .replaceAll('{device.state}', device.state.label);
}

String _requiredString(Map<dynamic, dynamic> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('"$key" is required');
  }
  return value;
}

String? _optionalString(Map<dynamic, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return null;
  return value.toString();
}

List<String> _stringList(dynamic value) {
  if (value == null) return const [];
  if (value is List) {
    return value.map((element) => element.toString()).toList();
  }
  throw const FormatException('expected a list of strings');
}

List<DeviceOs> _parsePlatforms(dynamic value) {
  if (value == null) return const [];
  if (value is! List) {
    throw const FormatException('"platforms" must be a list');
  }
  return value.map((element) {
    final name = element.toString().toLowerCase();
    return switch (name) {
      'android' => DeviceOs.android,
      'ios' => DeviceOs.ios,
      _ => throw FormatException('unknown platform: $element'),
    };
  }).toList();
}

String? _parseShortcut(dynamic value) {
  if (value == null) return null;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized.isEmpty) return null;
  return normalized;
}
