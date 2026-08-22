import 'dart:io';

import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_plugins/src/models/plugin_config.dart';

/// Outcome of launching a plugin command.
class PluginRunResult {
  /// Creates a run outcome with [success] and [message].
  const PluginRunResult({required this.success, required this.message});

  /// Whether the command launched successfully.
  final bool success;

  /// Human-readable status or error message.
  final String message;
}

/// Runs plugin commands as external processes and probes their availability.
abstract class PluginRunnerService {
  /// Whether the underlying executable for [plugin]/[command] is installed.
  Future<bool> isAvailable(PluginConfig plugin, PluginCommandConfig command);

  /// Launches [command] for [device], resolving argument templates.
  Future<PluginRunResult> run(PluginCommandConfig command, Device? device);
}

/// Default [PluginRunnerService] using [CommandExec] for probes.
class PluginRunnerServiceImpl implements PluginRunnerService {
  /// Creates a runner backed by [commandExec].
  PluginRunnerServiceImpl(this._commandExec);

  final CommandExec _commandExec;

  @override
  Future<bool> isAvailable(
    PluginConfig plugin,
    PluginCommandConfig command,
  ) async {
    final check = command.availability ?? plugin.availability;
    if (check == null) {
      return _probe(command.command, const ['--version']);
    }
    return _probe(check.command, check.args);
  }

  Future<bool> _probe(String executable, List<String> args) async {
    try {
      final result = await _commandExec.run(executable, arguments: args);
      return result.success;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<PluginRunResult> run(
    PluginCommandConfig command,
    Device? device,
  ) async {
    final args = command.resolveArgs(device);
    try {
      switch (command.mode) {
        case PluginRunMode.detached:
          await Process.start(
            command.command,
            args,
            mode: ProcessStartMode.detached,
          );
        case PluginRunMode.inherit:
          await Process.start(
            command.command,
            args,
            mode: ProcessStartMode.inheritStdio,
          );
      }
      return PluginRunResult(
        success: true,
        message: '${command.label} started',
      );
    } catch (e) {
      return PluginRunResult(
        success: false,
        message: 'Failed to run ${command.label}: $e',
      );
    }
  }
}
