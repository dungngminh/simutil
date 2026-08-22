/// Message kind sent to the command isolate.
enum IsolateCommand {
  /// Run an executable and return stdio.
  runCommand,

  /// Tear down the isolate loop.
  shutdown,
}

/// Request posted from the main isolate to [IsolateRunner].
class IsolateRequest {
  /// Creates a request identified by [id].
  const IsolateRequest({
    required this.id,
    required this.command,
    required this.executable,
    this.arguments = const [],
    this.workingDirectory,
    this.timeoutMs,
  });

  /// Correlation id matching [IsolateResponse.id].
  final int id;

  /// What the isolate should do.
  final IsolateCommand command;

  /// Executable name or path.
  final String executable;

  /// Arguments passed to [executable].
  final List<String> arguments;

  /// Optional working directory for the process.
  final String? workingDirectory;

  /// Optional timeout in milliseconds.
  final int? timeoutMs;
}

/// Result posted back from the command isolate.
class IsolateResponse {
  /// Creates a response for request [id].
  const IsolateResponse({
    required this.id,
    this.stdout = '',
    this.stderr = '',
    this.exitCode = -1,
    this.error,
  });

  /// Correlation id matching [IsolateRequest.id].
  final int id;

  /// Captured stdout.
  final String stdout;

  /// Captured stderr.
  final String stderr;

  /// Process exit code, or `-1` when [error] is set.
  final int exitCode;

  /// Failure string when the isolate could not run the process.
  final String? error;

  /// Whether the process exited `0` with no isolate-level [error].
  bool get success => exitCode == 0 && error == null;
}
