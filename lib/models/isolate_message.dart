/// Identifies the type of work to run on the background isolate.
enum IsolateCommand {
  /// Run a shell command (CLI process).
  runCommand,

  /// Gracefully shut down the background isolate.
  shutdown,
}

/// A request sent from the UI isolate → background isolate.
class IsolateRequest {
  /// Unique per-request identifier, used to pair responses.
  final int id;

  /// The command type to execute.
  final IsolateCommand command;

  /// The executable path (e.g. `adb`, `xcrun`).
  final String executable;

  /// Arguments to pass to the executable.
  final List<String> arguments;

  /// Optional working directory for the process.
  final String? workingDirectory;

  const IsolateRequest({
    required this.id,
    required this.command,
    required this.executable,
    this.arguments = const [],
    this.workingDirectory,
  });
}

/// A response sent from the background isolate → UI isolate.
class IsolateResponse {
  /// Matches [IsolateRequest.id].
  final int id;

  /// Standard output from the process.
  final String stdout;

  /// Standard error from the process.
  final String stderr;

  /// Process exit code.
  final int exitCode;

  /// Non-null when an exception was caught in the background isolate.
  final String? error;

  const IsolateResponse({
    required this.id,
    this.stdout = '',
    this.stderr = '',
    this.exitCode = -1,
    this.error,
  });

  /// Whether the command exited with code 0 and no error.
  bool get success => exitCode == 0 && error == null;
}
