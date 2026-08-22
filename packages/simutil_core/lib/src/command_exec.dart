import 'dart:io';

import 'package:simutil_core/src/isolate_runner.dart';

/// Outcome of a one-shot process invocation.
class CommandResult {
  /// Creates a result from captured stdio and [exitCode].
  const CommandResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  /// Data written to stdout.
  final String stdout;

  /// Data written to stderr.
  final String stderr;

  /// Process exit code. `0` means success.
  final int exitCode;

  /// Whether [exitCode] is `0`.
  bool get success => exitCode == 0;
}

/// Runs a command and waits for exit plus captured stdio.
///
/// Use [CommandExecImpl] from a CLI or tests. Use [IsolateCommandExec] from a
/// TUI so shell work does not block the UI isolate.
abstract class CommandExec {
  /// Runs [command] with [arguments] and returns stdout/stderr/exit code.
  Future<CommandResult> run(
    String command, {
    List<String> arguments,
    String? workingDirectory,
    Duration? timeout,
  });
}

/// [CommandExec] that calls `Process.run` on the current isolate.
class CommandExecImpl implements CommandExec {
  /// Creates an in-isolate executor.
  CommandExecImpl();

  @override
  Future<CommandResult> run(
    String command, {
    List<String> arguments = const [],
    String? workingDirectory,
    Duration? timeout,
  }) async {
    final resultFuture = Process.run(
      command,
      arguments,
      workingDirectory: workingDirectory,
    );
    final result = timeout == null
        ? await resultFuture
        : await resultFuture.timeout(timeout);
    return CommandResult(
      stdout: result.stdout as String,
      stderr: result.stderr as String,
      exitCode: result.exitCode,
    );
  }
}

/// [CommandExec] that forwards work to an [IsolateRunner] background isolate.
class IsolateCommandExec implements CommandExec {
  /// Creates an executor bound to an [IsolateRunner]. Call [IsolateRunner.init] first.
  const IsolateCommandExec(this._runner);

  final IsolateRunner _runner;

  @override
  Future<CommandResult> run(
    String command, {
    List<String> arguments = const [],
    String? workingDirectory,
    Duration? timeout,
  }) {
    return _runner.execute(
      command,
      arguments,
      workingDirectory: workingDirectory,
      timeout: timeout,
    );
  }
}
