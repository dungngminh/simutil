import 'dart:io';

import 'package:simutil/models/device.dart';
import 'package:simutil/models/plugin_config.dart';
import 'package:simutil/services/command_exec.dart';

/// Outcome of launching a plugin command.
class PluginRunResult {
  const PluginRunResult({required this.success, required this.message});

  final bool success;
  final String message;
}

/// Runs plugin commands as external processes and probes their availability.
abstract class PluginRunnerService {
  /// Whether the underlying executable for [plugin]/[command] is installed.
  Future<bool> isAvailable(PluginConfig plugin, PluginCommandConfig command);

  /// Launches [command] for [device], resolving argument templates.
  Future<PluginRunResult> run(PluginCommandConfig command, Device? device);
}

class PluginRunnerServiceImpl implements PluginRunnerService {
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
