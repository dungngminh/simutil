import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// One shard's outcome in a Maestro run (one shard runs on one device when
/// `--shard-all <deviceCount>` is used, so a shard maps to a device).
class MaestroShard {
  const MaestroShard({
    required this.shard,
    required this.device,
    required this.passed,
    required this.flow,
    required this.seconds,
  });

  /// 1-based shard index as Maestro prints it.
  final int shard;

  /// The device this shard ran on, when Maestro named it; else empty.
  final String device;

  /// Whether the shard's flow passed.
  final bool passed;

  /// The flow name Maestro reported.
  final String flow;

  /// How long the flow took, in seconds.
  final int seconds;

  Map<String, Object?> toJson() => {
    'shard': shard,
    if (device.isNotEmpty) 'device': device,
    'flow': flow,
    'passed': passed,
    'seconds': seconds,
  };
}

/// The result of a whole `maestro test` run.
class MaestroRunResult {
  const MaestroRunResult({
    required this.ok,
    required this.passed,
    required this.total,
    required this.shards,
    required this.output,
  });

  /// Every flow across every device passed.
  final bool ok;

  /// Flows that passed / flows run, from Maestro's summary.
  final int passed;
  final int total;

  /// Per-shard (per-device) outcomes.
  final List<MaestroShard> shards;

  /// The combined stdout/stderr, for debugging.
  final String output;

  /// The shard outcome for the device [deviceId] that ran at [index] in the
  /// run's device order. Matches by the device Maestro named first, then falls
  /// back to the 1-based shard number ([index] + 1). Returns null when no shard
  /// matches, since [shards] is compacted and sorted — a missing shard would
  /// otherwise make positional lookups return another device's result.
  MaestroShard? shardFor(String deviceId, int index) {
    for (final s in shards) {
      if (s.device.isNotEmpty && s.device == deviceId) return s;
    }
    for (final s in shards) {
      if (s.shard == index + 1) return s;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'ok': ok,
    'passed': passed,
    'total': total,
    'shards': [for (final s in shards) s.toJson()],
  };
}

/// Thrown when the Maestro CLI is not installed.
class MaestroNotInstalled implements Exception {
  const MaestroNotInstalled(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Runs Maestro flows on one or more devices through the `maestro` CLI,
/// in parallel via `--shard-all`. Spawns a long-running process, so it uses
/// [Process.start] rather than `CommandExec`.
class MaestroRunner {
  MaestroRunner({String? binary}) : _binary = binary ?? resolveBinary();

  final String _binary;
  Process? _process;

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
      final match = RegExp(
        r'\d+\.\d+\.\d+',
      ).firstMatch('${result.stdout}');
      return match?.group(0);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isAvailable() async => (await version()) != null;

  static final _shardLine = RegExp(
    r'\[shard (\d+)\] \[(Passed|Failed)\] (\S+) \((\d+)s\)',
  );
  static final _runningOn = RegExp(r'\[shard (\d+)\].*Running on (.+)$');
  static final _summary = RegExp(r'Passed:\s*(\d+)\s*/\s*(\d+)');

  Map<String, String> get _env => {
    ...Platform.environment,
    'MAESTRO_CLI_NO_ANALYTICS': '1',
  };

  /// Runs [flowYaml] on [deviceIds] in parallel — one shard per device, so
  /// the same flow runs on every device at once. [onLine] receives each
  /// output line as it arrives (for live progress). Throws
  /// [MaestroNotInstalled] when the CLI is missing.
  Future<MaestroRunResult> run({
    required String flowYaml,
    required List<String> deviceIds,
    void Function(String line)? onLine,
  }) async {
    if (deviceIds.isEmpty) {
      throw ArgumentError('No devices to run on');
    }
    if (_process != null) {
      throw StateError('A Maestro flow is already running; stop it first');
    }
    if (!await isAvailable()) throw const MaestroNotInstalled(installHint);

    final dir = await Directory.systemTemp.createTemp('simutil-maestro-');
    final flows = Directory('${dir.path}/flows')..createSync();
    File('${flows.path}/flow.yaml').writeAsStringSync(flowYaml);
    try {
      final args = [
        '--device',
        deviceIds.join(','),
        'test',
        '--shard-all',
        '${deviceIds.length}',
        flows.path,
      ];
      final proc = await Process.start(_binary, args, environment: _env);
      _process = proc;

      final output = StringBuffer();
      final shardDevice = <int, String>{};
      final shards = <int, MaestroShard>{};
      int? passed, total;

      void handle(String line) {
        output.writeln(line);
        onLine?.call(line);
        if (_runningOn.firstMatch(line) case final r?) {
          shardDevice[int.parse(r.group(1)!)] = r.group(2)!.trim();
        }
        if (_shardLine.firstMatch(line) case final m?) {
          final shard = int.parse(m.group(1)!);
          shards[shard] = MaestroShard(
            shard: shard,
            device: shardDevice[shard] ?? '',
            passed: m.group(2) == 'Passed',
            flow: m.group(3)!,
            seconds: int.parse(m.group(4)!),
          );
        }
        if (_summary.firstMatch(line) case final s?) {
          passed = int.parse(s.group(1)!);
          total = int.parse(s.group(2)!);
        }
      }

      // Drain both streams to completion before reading the exit code:
      // `exitCode` can complete before stdout/stderr deliver their last lines,
      // which are the per-shard results and the `Passed: x/y` summary.
      final outDone = proc.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(handle)
          .asFuture<void>();
      final errDone = proc.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(handle)
          .asFuture<void>();
      await Future.wait([outDone, errDone]);
      final code = await proc.exitCode;
      _process = null;

      final shardList = shards.values.toList()
        ..sort((a, b) => a.shard.compareTo(b.shard));
      final ran = total ?? deviceIds.length;
      final ok = code == 0 && (passed ?? 0) == ran && shardList.every((s) => s.passed);
      return MaestroRunResult(
        ok: ok,
        passed: passed ?? shardList.where((s) => s.passed).length,
        total: ran,
        shards: shardList,
        output: output.toString(),
      );
    } finally {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  /// Stops the running `maestro test`, if any.
  void stop() {
    _process?.kill();
    _process = null;
  }

  /// Whether a run is in progress.
  bool get running => _process != null;
}
