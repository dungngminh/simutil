import 'package:simutil_core/simutil_core.dart';

/// Lightweight configurable [CommandExec] fake for service tests.
///
/// Dispatches each `run` call to [handler] (keyed on command + arguments) and
/// records every invocation so tests can assert on what was executed.
class FakeCommandExec implements CommandExec {
  /// Creates a fake that consults [handler] for each [run].
  FakeCommandExec(this.handler);

  /// Returns a result for a given command + arguments, or `null` to fall back
  /// to a default failing result.
  CommandResult? Function(String command, List<String> arguments) handler;

  /// Recorded [run] invocations, in order.
  final List<FakeCommandCall> calls = [];

  /// Successful result helper (`exitCode` 0).
  static CommandResult ok([String stdout = '', String stderr = '']) =>
      CommandResult(stdout: stdout, stderr: stderr, exitCode: 0);

  /// Failing result helper.
  static CommandResult fail([
    String stderr = '',
    String stdout = '',
    int exitCode = 1,
  ]) => CommandResult(stdout: stdout, stderr: stderr, exitCode: exitCode);

  @override
  Future<CommandResult> run(
    String command, {
    List<String> arguments = const [],
    String? workingDirectory,
    Duration? timeout,
  }) async {
    calls.add(
      FakeCommandCall(
        command: command,
        arguments: List.unmodifiable(arguments),
        workingDirectory: workingDirectory,
        timeout: timeout,
      ),
    );
    return handler(command, arguments) ??
        const CommandResult(stdout: '', stderr: '', exitCode: 1);
  }
}

/// One recorded [FakeCommandExec.run] call.
class FakeCommandCall {
  /// Creates a recorded invocation.
  const FakeCommandCall({
    required this.command,
    required this.arguments,
    this.workingDirectory,
    this.timeout,
  });

  /// Executable that was requested.
  final String command;

  /// Arguments passed to [command].
  final List<String> arguments;

  /// Working directory passed to [CommandExec.run], if any.
  final String? workingDirectory;

  /// Timeout passed to [CommandExec.run], if any.
  final Duration? timeout;
}
