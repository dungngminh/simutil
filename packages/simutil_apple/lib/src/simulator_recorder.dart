import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Records a booted simulator's screen with `simctl io recordVideo`.
abstract interface class SimulatorRecorder {
  /// Creates a recorder for simulator [udid].
  factory SimulatorRecorder(String udid) = _SimulatorRecorder;

  /// Whether a recording is running; false again once `simctl` stopped on
  /// its own (e.g. the simulator shut down).
  bool get isRecording;

  /// Starts writing an H.264 `.mp4` to [path]; completes once `simctl`
  /// records. Throws a [StateError] with `simctl`'s error when it cannot
  /// (e.g. the file cannot be created).
  Future<void> start(String path);

  /// Stops and finalizes the file; returns its path, or null when the
  /// recording failed or was not finalized.
  Future<String?> stop();
}

class _SimulatorRecorder implements SimulatorRecorder {
  _SimulatorRecorder(this.udid);

  final String udid;
  Process? _process;
  String? _path;

  /// The start in progress: a second [start] joins it instead of launching
  /// another `simctl`, and [stop] waits for it.
  Future<void>? _starting;

  /// How long `simctl` may take to report `Recording started`.
  static const _startTimeout = Duration(seconds: 15);

  @override
  bool get isRecording => _process != null;

  @override
  Future<void> start(String path) {
    if (_process != null) return Future.value();
    return _starting ??= _start(path).whenComplete(() => _starting = null);
  }

  Future<void> _start(String path) async {
    // Long-lived until stopped: Process.start, not CommandExec.
    final process = await Process.start('xcrun', [
      'simctl',
      'io',
      udid,
      'recordVideo',
      '--codec=h264',
      '--force',
      path,
    ]);
    unawaited(process.stdout.drain<void>());
    final stderr = StringBuffer();
    final started = Completer<bool>();
    process.stderr.transform(utf8.decoder).listen((text) {
      stderr.write(text);
      if (stderr.toString().contains('Recording started') &&
          !started.isCompleted) {
        started.complete(true);
      }
    }, onError: (Object _) {});
    unawaited(
      process.exitCode.then((_) {
        if (!started.isCompleted) started.complete(false);
        // Ended on its own: no recording to stop any more.
        if (identical(_process, process)) {
          _process = null;
          _path = null;
        }
      }),
    );

    final ok = await started.future.timeout(
      _startTimeout,
      onTimeout: () => false,
    );
    if (!ok) {
      process.kill();
      // So a retry does not overlap the failed simctl.
      await process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () => -1,
      );
      throw StateError('Recording failed: ${_lastLine(stderr.toString())}');
    }
    _process = process;
    _path = path;
  }

  /// simctl finalizes the movie on SIGINT, not on SIGTERM.
  @override
  Future<String?> stop() async {
    // A stream closed while its recording starts: let the start finish,
    // then stop what it started rather than leave it running.
    if (_starting case final starting?) {
      try {
        await starting;
      } catch (_) {}
    }
    final process = _process;
    final path = _path;
    _process = null;
    _path = null;
    if (process == null) return null;
    process.kill(ProcessSignal.sigint);
    final code = await process.exitCode.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        process.kill();
        return -1;
      },
    );
    return code == 0 && path != null && File(path).existsSync() ? path : null;
  }

  /// The message after simctl's `An error was encountered …` line (e.g.
  /// `Cannot create file`), else its last line.
  static String _lastLine(String output) {
    final lines = output
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('Note:'))
        .toList();
    final error = lines.indexWhere((l) => l.startsWith('An error was'));
    if (error >= 0 && error + 1 < lines.length) return lines[error + 1];
    return lines.lastOrNull ?? 'simctl did not start recording';
  }
}
