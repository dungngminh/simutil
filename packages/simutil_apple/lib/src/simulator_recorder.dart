import 'dart:async';
import 'dart:io';

/// Records a booted simulator's screen with `simctl io recordVideo`.
abstract interface class SimulatorRecorder {
  /// Creates a recorder for simulator [udid].
  factory SimulatorRecorder(String udid) = _SimulatorRecorder;

  /// Whether a recording is running.
  bool get isRecording;

  /// Starts writing an H.264 `.mp4` to [path].
  Future<void> start(String path);

  /// Stops and finalizes the file; returns its path.
  Future<String?> stop();
}

class _SimulatorRecorder implements SimulatorRecorder {
  _SimulatorRecorder(this.udid);

  final String udid;
  Process? _process;
  String? _path;

  @override
  bool get isRecording => _process != null;

  @override
  Future<void> start(String path) async {
    if (_process != null) return;
    // Long-lived until stopped: Process.start, not CommandExec.
    _process = await Process.start('xcrun', [
      'simctl',
      'io',
      udid,
      'recordVideo',
      '--codec=h264',
      '--force',
      path,
    ]);
    unawaited(_process!.stdout.drain<void>());
    unawaited(_process!.stderr.drain<void>());
    _path = path;
  }

  /// simctl finalizes the movie on SIGINT, not on SIGTERM.
  @override
  Future<String?> stop() async {
    final process = _process;
    final path = _path;
    _process = null;
    _path = null;
    if (process == null) return null;
    process.kill(ProcessSignal.sigint);
    await process.exitCode.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        process.kill();
        return -1;
      },
    );
    return path;
  }
}
