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
    final child = await Process.start(
      _currentExecutableCommand(),
      _currentExecutableArguments(),
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

/// Leaves the alternate screen, shows the cursor and resets attributes.
///
/// `tput` prints the terminal's own sequences; `Process.run` captures them,
/// so they are written to the terminal here, followed by the xterm ones for
/// terminals without terminfo entries (repeating them is harmless).
Future<void> _restoreTerminalScreenState() async {
  final sequences = StringBuffer();
  final term = Platform.environment['TERM'];
  if (term != null && term.isNotEmpty) {
    for (final capability in const ['rmcup', 'cnorm', 'sgr0']) {
      try {
        final result = await Process.run('tput', [capability]);
        if (result.exitCode == 0) sequences.write(result.stdout);
      } catch (_) {}
    }
  }
  sequences.write(xtermRestoreSequence);
  try {
    writeToTerminal(sequences.toString());
  } catch (_) {}
}

/// Leaves the alternate screen (`?1049l`), shows the cursor (`?25h`) and
/// resets attributes.
const xtermRestoreSequence = '\x1b[?1049l\x1b[?25h\x1b[0m\r';

/// Writes [data] to the controlling terminal at [path].
///
/// Opens write-only: append mode seeks to the end, which fails on a tty
/// with `Illegal seek` (errno 29).
void writeToTerminal(String data, {String path = '/dev/tty'}) {
  final tty = File(path).openSync(mode: FileMode.writeOnly);
  try {
    tty.writeStringSync(data);
  } finally {
    tty.closeSync();
  }
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
