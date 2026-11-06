import 'dart:async';
import 'dart:io';

const _tuiChildEnvVar = 'SIMUTIL_TUI_CHILD';

/// Whether this process should supervise a TUI child process.
///
/// On Linux the TUI runs in a re-executed child so the parent can restore the
/// terminal (termios, alternate screen) reliably after the child exits.
bool get shouldSuperviseTui =>
    Platform.isLinux && Platform.environment[_tuiChildEnvVar] != '1';

/// Re-runs the current executable as a TUI child with inherited stdio,
/// forwards signals to it, and restores the terminal when it exits.
Future<void> runTuiSupervisor() => _runTuiSupervisor();

Future<void> _runTuiSupervisor() async {
  final ttyState = await _captureTerminalState();
  var childExited = false;
  final signalSubscriptions = <StreamSubscription<ProcessSignal>>[];
  try {
    final (command, arguments) = tuiChildCommand(
      compiled: const bool.fromEnvironment('dart.vm.product'),
      script: Platform.script.toFilePath(),
      executable: Platform.resolvedExecutable,
      executableArguments: Platform.executableArguments,
    );
    final child = await Process.start(
      command,
      arguments,
      mode: ProcessStartMode.inheritStdio,
      environment: {...Platform.environment, _tuiChildEnvVar: '1'},
    );
    signalSubscriptions.addAll(
      _forwardSignalsToChild(child.pid, isChildExited: () => childExited),
    );
    final childExitCode = await child.exitCode;
    childExited = true;
    exitCode = childExitCode;
  } finally {
    childExited = true;
    for (final subscription in signalSubscriptions) {
      await subscription.cancel();
    }
    await _restoreTerminalState(ttyState);
  }
}

/// The command that runs this program again as the TUI child.
///
/// A [compiled] (AOT) executable restarts as is: its [script] is whatever
/// path it was started by (a symlink, or not even a real path when found on
/// `PATH`), and passing it on would start the CLI instead of the TUI. Run by
/// the Dart VM ([script] is a `.dart` file, or the `.snapshot` that
/// `dart pub global run` uses), the VM gets its flags and the script again.
(String, List<String>) tuiChildCommand({
  required bool compiled,
  required String script,
  required String executable,
  required List<String> executableArguments,
}) {
  if (compiled) return ('/proc/self/exe', const []);
  return (executable, [...executableArguments, script]);
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
  final term = Platform.environment['TERM'];

  if (term != null && term.isNotEmpty) {
    await Process.run('tput', ['rmcup']);
    await Process.run('tput', ['cnorm']);
    await Process.run('tput', ['sgr0']);
  }

  try {
    final tty = File('/dev/tty').openSync(mode: FileMode.writeOnlyAppend);
    try {
      tty.writeStringSync('\x1b[?1049l\x1b[?25h\x1b[0m\r');
    } finally {
      tty.closeSync();
    }
  } catch (_) {}
}

List<StreamSubscription<ProcessSignal>> _forwardSignalsToChild(
  int pid, {
  required bool Function() isChildExited,
}) {
  if (!(Platform.isLinux || Platform.isMacOS)) return const [];

  return [
    ProcessSignal.sigwinch.watch().listen((_) {
      if (isChildExited()) return;
      Process.killPid(pid, ProcessSignal.sigwinch);
    }),
    ProcessSignal.sigterm.watch().listen((_) {
      if (isChildExited()) return;
      Process.killPid(pid, ProcessSignal.sigterm);
    }),
    ProcessSignal.sighup.watch().listen((_) {
      if (isChildExited()) return;
      Process.killPid(pid, ProcessSignal.sighup);
    }),
    ProcessSignal.sigint.watch().listen((_) {
      if (isChildExited()) return;
      Process.killPid(pid, ProcessSignal.sigint);
    }),
  ];
}
