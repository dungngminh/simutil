import 'dart:async';
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
/// `CommandExec()` runs on the current isolate (CLI, tests). Use
/// `CommandExec.isolate` from a TUI so shell work does not block the UI isolate.
abstract interface class CommandExec {
  /// Creates an executor that runs processes on the current isolate.
  const factory CommandExec() = _ProcessCommandExec;

  /// Creates an executor that forwards work to [runner]'s background isolate.
  /// Call [IsolateRunner.init] first.
  const factory CommandExec.isolate(IsolateRunner runner) = _IsolateCommandExec;

  /// Runs [command] with [arguments] and returns stdout/stderr/exit code.
  ///
  /// When [timeout] elapses the process is killed and a [TimeoutException]
  /// is thrown.
  Future<CommandResult> run(
    String command, {
    List<String> arguments,
    String? workingDirectory,
    Duration? timeout,
  });
}

class _ProcessCommandExec implements CommandExec {
  const _ProcessCommandExec();

  @override
  Future<CommandResult> run(
    String command, {
    List<String> arguments = const [],
    String? workingDirectory,
    Duration? timeout,
  }) async {
    final process = await Process.start(
      command,
      arguments,
      workingDirectory: workingDirectory,
    );
    final stdout = process.stdout.transform(systemEncoding.decoder).join();
    final stderr = process.stderr.transform(systemEncoding.decoder).join();
    final exitCode = timeout == null
        ? await process.exitCode
        : await process.exitCode.timeout(
            timeout,
            onTimeout: () {
              process.kill(ProcessSignal.sigkill);
              throw TimeoutException(
                'Command timed out after ${timeout.inSeconds} seconds',
                timeout,
              );
            },
          );
    return CommandResult(
      stdout: await stdout,
      stderr: await stderr,
      exitCode: exitCode,
    );
  }
}

class _IsolateCommandExec implements CommandExec {
  const _IsolateCommandExec(this._runner);

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
