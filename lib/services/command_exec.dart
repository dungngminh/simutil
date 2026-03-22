import 'dart:io';

import 'package:simutil/services/isolate_runner.dart';

class CommandResult {
  const CommandResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });
  final String stdout;
  final String stderr;
  final int exitCode;

  bool get success => exitCode == 0;
}

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

class IsolateCommandExec implements CommandExec {
  const IsolateCommandExec(this._runner);

  final IsolateRunner _runner;

  @override
  Future<CommandResult> run(
    String command, {
    List<String> arguments = const [],
    String? workingDirectory,
  }) {
    return _runner.execute(
      command,
      arguments,
      workingDirectory: workingDirectory,
    );
  }
}
