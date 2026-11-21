import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// One device's outcome in a Maestro run.
class MaestroDeviceResult {
  const MaestroDeviceResult({
    required this.deviceId,
    required this.passed,
    required this.seconds,
    this.error,
  });

  final String deviceId;

  /// Whether the flow passed on this device.
  final bool passed;

  /// How long the flow took on this device, in seconds.
  final int seconds;

  /// The first failure Maestro reported, e.g.
  /// `Assertion is false: "Settings" is visible`.
  final String? error;

  Map<String, Object?> toJson() => {
    'device': deviceId,
    'passed': passed,
    'seconds': seconds,
    'error': ?error,
  };
}

/// The result of running a flow on every device.
class MaestroRunResult {
  const MaestroRunResult({required this.devices, required this.output});

  /// Per-device outcomes, in the run's device order; empty when stopped
  /// before any device started.
  final List<MaestroDeviceResult> devices;

  /// Every device's output, for debugging.
  final String output;

  int get passed => devices.where((d) => d.passed).length;
  int get total => devices.length;
  bool get ok => devices.isNotEmpty && devices.every((d) => d.passed);

  /// [deviceId]'s outcome, or null when it never finished.
  MaestroDeviceResult? deviceFor(String deviceId) {
    for (final d in devices) {
      if (d.deviceId == deviceId) return d;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'ok': ok,
    'passed': passed,
    'total': total,
    'devices': [for (final d in devices) d.toJson()],
  };
}

/// Thrown when the Maestro CLI is not installed.
class MaestroNotInstalled implements Exception {
  const MaestroNotInstalled(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Runs Maestro flows on one or more devices through the `maestro` CLI: one
/// `maestro test` per device, all at once, so each device reports its steps
/// live. Spawns long-running processes, so it uses [Process.start] rather
/// than `CommandExec`.
class MaestroRunner {
  MaestroRunner({String? binary}) : _binary = binary ?? resolveBinary();

  final String _binary;
  final _processes = <Process>{};

  /// Held for the whole of a [run], from before the first `await` until its
  /// `finally`, so overlapping runs are rejected even while the CLI is probed.
  bool _busy = false;

  /// Set by [stop]; checked after each `await` in [run] so a stop during the
  /// CLI probe or process start cancels the launch instead of leaking a run.
  bool _canceled = false;

  /// How to install Maestro, shown when it is missing.
  static const installHint =
      'Maestro is not installed. Install it with:\n'
      '  curl -Ls "https://get.maestro.mobile.dev" | bash\n'
      'then reopen SimUtil, or set the MAESTRO env var to its path.';

  /// The `maestro` binary: `$MAESTRO`, the default install under
  /// `~/.maestro/bin`, a Homebrew install, then bare `maestro` on PATH.
  static String resolveBinary() {
    final env = Platform.environment;
    final home = env['HOME'] ?? '';
    for (final path in [
      ?env['MAESTRO'],
      if (home.isNotEmpty) '$home/.maestro/bin/maestro',
      '/opt/homebrew/bin/maestro',
      '/usr/local/bin/maestro',
    ]) {
      if (File(path).existsSync()) return path;
    }
    return 'maestro';
  }

  /// The installed Maestro version, or null when it cannot be run.
  Future<String?> version() async {
    try {
      final result = await Process.run(_binary, [
        '--version',
      ], environment: _env);
      if (result.exitCode != 0) return null;
      // The first non-banner line that looks like a version.
      final match = RegExp(r'\d+\.\d+\.\d+').firstMatch('${result.stdout}');
      return match?.group(0);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isAvailable() async => (await version()) != null;

  Map<String, String> get _env => {
    ...Platform.environment,
    'MAESTRO_CLI_NO_ANALYTICS': '1',
  };

  /// A top-level command's result line, e.g. `Tap on "General"... COMPLETED`.
  /// Nested commands (inside repeat, runFlow, …) are indented and skipped,
  /// so the Nth match is the flow's Nth top-level command.
  static final _stepLine = RegExp(
    r'^\S.*\.\.\. (COMPLETED|FAILED|SKIPPED|WARNED)$',
  );

  /// Runs [flowYaml] on [deviceIds] at once, one `maestro test` each.
  /// [onLine] gets each device's output lines as they arrive; [onStep] gets
  /// each top-level command's result (its 0-based index and whether it
  /// passed). Throws [MaestroNotInstalled] when the CLI is missing.
  Future<MaestroRunResult> run({
    required String flowYaml,
    required List<String> deviceIds,
    void Function(String deviceId, String line)? onLine,
    void Function(String deviceId, int step, {required bool passed})? onStep,
  }) async {
    if (deviceIds.isEmpty) {
      throw ArgumentError('No devices to run on');
    }
    // Claim the run slot synchronously, before the first await. The panel and
    // the MCP tool share this singleton, so a guard that only checks after an
    // await (e.g. `isAvailable()` spinning up a JVM) would let two calls in.
    if (_busy) {
      throw StateError('A Maestro flow is already running; stop it first');
    }
    _busy = true;
    _canceled = false;

    Directory? dir;
    try {
      if (!await isAvailable()) throw const MaestroNotInstalled(installHint);
      if (_canceled) return _stopped;

      dir = await Directory.systemTemp.createTemp('simutil-maestro-');
      final flow = File('${dir.path}/flow.yaml')..writeAsStringSync(flowYaml);
      final output = StringBuffer();
      final results = await Future.wait([
        for (final id in deviceIds)
          _runOn(
            id,
            flow.path,
            onLine: (line) {
              output.writeln(line);
              onLine?.call(id, line);
            },
            onStep: (step, {required passed}) =>
                onStep?.call(id, step, passed: passed),
          ),
      ]);
      return MaestroRunResult(
        devices: [for (final r in results) ?r],
        output: output.toString(),
      );
    } finally {
      _busy = false;
      if (dir != null) {
        try {
          dir.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
  }

  /// One device's `maestro test`; null when stopped before it started.
  Future<MaestroDeviceResult?> _runOn(
    String deviceId,
    String flowPath, {
    required void Function(String line) onLine,
    required void Function(int step, {required bool passed}) onStep,
  }) async {
    if (_canceled) return null;
    final clock = Stopwatch()..start();
    final process = await Process.start(_binary, [
      '--device',
      deviceId,
      'test',
      '--no-ansi',
      flowPath,
    ], environment: _env);
    _processes.add(process);
    try {
      // A stop that landed while the process was starting still needs to
      // kill it, since stop() did not see it yet.
      if (_canceled) {
        process.kill();
        return null;
      }
      var step = 0;
      var awaitingError = false;
      String? error;
      void handle(String line) {
        onLine(line);
        if (awaitingError && line.trim().isNotEmpty) {
          error = line.trim();
          awaitingError = false;
        }
        if (_stepLine.firstMatch(line) case final m?) {
          final failed = m.group(1) == 'FAILED';
          onStep(step++, passed: !failed);
          if (failed && error == null) awaitingError = true;
        }
      }

      // Drain both streams before reading the exit code, which can complete
      // before the last lines arrive. Decode leniently so a stray non-UTF-8
      // byte from the JVM can't abort the read.
      const decoder = Utf8Decoder(allowMalformed: true);
      Future<void> drain(Stream<List<int>> s) => s
          .transform(decoder)
          .transform(const LineSplitter())
          .listen(handle)
          .asFuture<void>();
      try {
        await Future.wait([drain(process.stdout), drain(process.stderr)]);
      } catch (_) {
        process.kill();
        rethrow;
      }
      final code = await process.exitCode;
      if (_canceled) return null;
      return MaestroDeviceResult(
        deviceId: deviceId,
        passed: code == 0,
        seconds: clock.elapsed.inSeconds,
        error: code == 0 ? null : error ?? 'Maestro exited with code $code',
      );
    } finally {
      _processes.remove(process);
    }
  }

  static const _stopped = MaestroRunResult(devices: [], output: '');

  /// Stops every running `maestro test`. Sets the cancel flag so a launch
  /// still in its `await`s is abandoned. The owning [run] clears `_busy` in
  /// its `finally`.
  void stop() {
    _canceled = true;
    for (final p in _processes) {
      p.kill();
    }
  }

  /// Whether a run is in progress.
  bool get running => _busy;
}
