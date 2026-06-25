import 'package:simutil/services/command_exec.dart';

/// Lightweight configurable [CommandExec] fake for service tests.
///
/// Dispatches each `run` call to [handler] (keyed on command + arguments) and
/// records every invocation so tests can assert on what was executed.
class FakeCommandExec implements CommandExec {
  FakeCommandExec(this.handler);

  /// Returns a result for a given command + arguments, or `null` to fall back
  /// to a default failing result.
  CommandResult? Function(String command, List<String> arguments) handler;

  final List<FakeCommandCall> calls = [];

  static CommandResult ok([String stdout = '', String stderr = '']) =>
      CommandResult(stdout: stdout, stderr: stderr, exitCode: 0);

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

class FakeCommandCall {
  const FakeCommandCall({
    required this.command,
    required this.arguments,
    this.workingDirectory,
    this.timeout,
  });

  final String command;
  final List<String> arguments;
  final String? workingDirectory;
  final Duration? timeout;
}
