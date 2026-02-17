import 'dart:io';

/// Result of executing a shell command.
class CommandResult {
  final String stdout;
  final String stderr;
  final int exitCode;

  const CommandResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  /// Whether the command exited with code 0.
  bool get success => exitCode == 0;
}

/// Abstraction for running shell commands.
abstract class CommandExec {
  Future<CommandResult> run(
    String command, {
    List<String> arguments,
    String? workingDirectory,
  });
}

class CommandExecImpl implements CommandExec {
  @override
  Future<CommandResult> run(
    String command, {
    List<String> arguments = const [],
    String? workingDirectory,
  }) async {
    final result = await Process.run(
      command,
      arguments,
      workingDirectory: workingDirectory,
    );
    return CommandResult(
      stdout: result.stdout as String,
      stderr: result.stderr as String,
      exitCode: result.exitCode,
    );
  }
}
