import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/cli/simutil_command_runner.dart';
import 'package:simutil/simutil_app.dart';

const _tuiChildEnvVar = 'SIMUTIL_TUI_CHILD';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    if (Platform.isLinux && Platform.environment[_tuiChildEnvVar] != '1') {
      await _runTuiSupervisor();
      return;
    }

    await runApp(Navigator(home: const SimutilApp()));
  } else {
    await SimutilCommandRunner().run(arguments);
  }
}

Future<void> _runTuiSupervisor() async {
  final ttyState = await _captureTerminalState();
  try {
    final child = await Process.start(
      _currentExecutableCommand(),
      _currentExecutableArguments(),
      mode: ProcessStartMode.inheritStdio,
      environment: {...Platform.environment, _tuiChildEnvVar: '1'},
    );
    exitCode = await child.exitCode;
  } finally {
    await _restoreTerminalState(ttyState);
  }
}

String _currentExecutableCommand() {
  final scriptPath = Platform.script.toFilePath();
  if (scriptPath.endsWith('.dart')) {
    return Platform.resolvedExecutable;
  }
  return '/proc/self/exe';
}

List<String> _currentExecutableArguments() {
  final scriptPath = Platform.script.toFilePath();
  if (scriptPath.endsWith('.dart')) {
    return [...Platform.executableArguments, scriptPath];
  }
  return const [];
}

Future<String?> _captureTerminalState() async {
  try {
    if (!stdin.hasTerminal || !(Platform.isLinux || Platform.isMacOS)) {
      return null;
    }
    final result = await _runStty(['-g']);
    if (result.exitCode != 0) return null;

    final state = (result.stdout as String).trim();
    return state.isEmpty ? null : state;
  } catch (_) {
    return null;
  }
}

Future<void> _restoreTerminalState(String? ttyState) async {
  try {
    if (!stdin.hasTerminal || !(Platform.isLinux || Platform.isMacOS)) return;
    // Restore the exact pre-TUI termios state from the parent process after the
    // child TUI exits. On SSH PTYs this is more reliable than in-process
    // restoration from the TUI itself.
    if (ttyState != null) {
      await _runStty([ttyState]);
    } else {
      await _runStty(['sane']);
    }
    await _restoreTerminalScreenState();
  } catch (_) {}
}

Future<ProcessResult> _runStty(List<String> arguments) {
  final ttyFlag = Platform.isMacOS ? '-f' : '-F';
  return Process.run('stty', [ttyFlag, '/dev/tty', ...arguments]);
}

Future<void> _restoreTerminalScreenState() async {
  final shell = Platform.environment['SHELL'] ?? '/bin/sh';
  final term = Platform.environment['TERM'];

  if (term != null && term.isNotEmpty) {
    await Process.run('tput', ['rmcup']);
    await Process.run('tput', ['cnorm']);
    await Process.run('tput', ['sgr0']);
  }

  await Process.run(shell, [
    '-lc',
    "printf '\\033[?1049l\\033[?25h\\033[0m\\r' > /dev/tty",
  ]);
}
