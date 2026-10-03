import 'dart:io';

import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_plugins/src/models/plugin_config.dart';

/// Outcome of launching a plugin command.
final class PluginRunResult {
  /// Creates a run outcome with [success] and [message].
  const PluginRunResult({
    required this.success,
    required this.message,
    this.exitCode,
  });

  /// Whether the command launched (detached) or exited with `0` (inherit).
  final bool success;

  /// Exit code of an `inherit` command; `null` for detached launches and
  /// launch failures.
  final int? exitCode;

  /// Human-readable status or error message.
  final String message;
}

/// Runs plugin commands as external processes and probes their availability.
abstract interface class PluginRunner {
  /// Default runner: probes through [commandExec], launches with
  /// `Process.start` so GUI / long-running tools outlive the call.
  factory PluginRunner(CommandExec commandExec) = _ProcessPluginRunner;

  /// Whether the underlying executable for [plugin]/[command] is installed.
  Future<bool> isAvailable(PluginConfig plugin, PluginCommandConfig command);

  /// Launches [command] for [device], resolving argument templates.
  ///
  /// Detached commands return once started. Inherit commands complete when
  /// the process exits and report its exit code.
  Future<PluginRunResult> run(PluginCommandConfig command, Device? device);
}

final class _ProcessPluginRunner implements PluginRunner {
  _ProcessPluginRunner(this._commandExec);

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
          return PluginRunResult(
            success: true,
            message: '${command.label} started',
          );
        case PluginRunMode.inherit:
          final process = await Process.start(
            command.command,
            args,
            mode: ProcessStartMode.inheritStdio,
          );
          final exitCode = await process.exitCode;
          return PluginRunResult(
            success: exitCode == 0,
            message: exitCode == 0
                ? '${command.label} finished'
                : '${command.label} exited with code $exitCode',
            exitCode: exitCode,
          );
      }
    } catch (e) {
      return PluginRunResult(
        success: false,
        message: 'Failed to run ${command.label}: $e',
      );
    }
  }
}
