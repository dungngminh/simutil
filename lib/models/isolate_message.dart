enum IsolateCommand { runCommand, shutdown }

class IsolateRequest {
  const IsolateRequest({
    required this.id,
    required this.command,
    required this.executable,
    this.arguments = const [],
    this.workingDirectory,
  });

  final int id;
  final IsolateCommand command;
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
}

class IsolateResponse {
  const IsolateResponse({
    required this.id,
    this.stdout = '',
    this.stderr = '',
    this.exitCode = -1,
    this.error,
  });

  final int id;
  final String stdout;
  final String stderr;
  final int exitCode;
  final String? error;

  bool get success => exitCode == 0 && error == null;
}
