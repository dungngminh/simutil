import 'package:bloc_signals/bloc_signals.dart';
import 'package:equatable/equatable.dart';
import 'package:simutil_app/src/maestro/maestro_runner.dart';

/// Where a device (or a whole run) stands in a Maestro flow run.
enum ScenarioStatus { running, ok, failed, stopped }

/// One device's outcome in a Maestro run (one shard per device).
final class ScenarioDeviceRun extends Equatable {
  const ScenarioDeviceRun({
    required this.deviceId,
    required this.name,
    this.status = ScenarioStatus.running,
    this.seconds,
    this.error,
    this.stepsDone = 0,
    this.failedStep,
    this.lines = const [],
  });

  final String deviceId;
  final String name;
  final ScenarioStatus status;

  /// How long the flow took on this device, once finished.
  final int? seconds;

  /// Failure message when [status] is failed.
  final String? error;

  /// How many of the flow's top-level commands finished (passed or failed).
  final int stepsDone;

  /// The 0-based top-level command that failed, if one did.
  final int? failedStep;

  /// This device's own Maestro output.
  final List<String> lines;

  /// Where top-level command [step] stands on this device, or null when it
  /// has not started (or never will).
  ScenarioStatus? stepStatus(int step) => step == failedStep
      ? ScenarioStatus.failed
      : step < stepsDone
      ? ScenarioStatus.ok
      : step == stepsDone && status == ScenarioStatus.running
      ? ScenarioStatus.running
      : null;

  ScenarioDeviceRun copyWith({
    ScenarioStatus? status,
    int? seconds,
    String? error,
    int? stepsDone,
    int? failedStep,
    List<String>? lines,
  }) => ScenarioDeviceRun(
    deviceId: deviceId,
    name: name,
    status: status ?? this.status,
    seconds: seconds ?? this.seconds,
    error: error ?? this.error,
    stepsDone: stepsDone ?? this.stepsDone,
    failedStep: failedStep ?? this.failedStep,
    lines: lines ?? this.lines,
  );

  @override
  List<Object?> get props => [
    deviceId,
    name,
    status,
    seconds,
    error,
    stepsDone,
    failedStep,
    lines,
  ];
}

/// One Maestro flow run across its devices (run in parallel via shards).
final class ScenarioRun extends Equatable {
  const ScenarioRun({
    required this.id,
    required this.startedAt,
    required this.devices,
    this.source = '',
    this.lines = const [],
  });

  final int id;
  final DateTime startedAt;
  final List<ScenarioDeviceRun> devices;

  /// The Maestro flow YAML that ran.
  final String source;

  /// Maestro's output lines, for the live log.
  final List<String> lines;

  ScenarioStatus get status =>
      devices.any((d) => d.status == ScenarioStatus.running)
      ? ScenarioStatus.running
      : devices.any((d) => d.status == ScenarioStatus.failed)
      ? ScenarioStatus.failed
      : devices.any((d) => d.status == ScenarioStatus.stopped)
      ? ScenarioStatus.stopped
      : ScenarioStatus.ok;

  @override
  List<Object?> get props => [id, startedAt, devices, source, lines];
}

/// Maestro flow runs, newest first, for the scenarios panel.
class ScenarioRunsCubit extends CubitSignal<List<ScenarioRun>> {
  ScenarioRunsCubit() : super(initialState: const []);

  /// ponytail: keeps the last [_keep] runs in memory; persist if users need
  /// history across launches.
  static const _keep = 20;
  static const _maxLines = 400;
  var _nextId = 0;
  final _stopped = <int>{};

  /// Asks run [id] to stop (the runner kills the maestro process).
  void stop(int id) => _stopped.add(id);

  /// Asks every running run to stop; returns their ids.
  List<int> stopAll() {
    final ids = [
      for (final r in stateValue)
        if (r.status == ScenarioStatus.running) r.id,
    ];
    _stopped.addAll(ids);
    return ids;
  }

  /// Whether run [id] was asked to stop.
  bool isStopped(int id) => _stopped.contains(id);

  /// Records a run starting on [devices] (id → name) with its [source] YAML;
  /// returns its id. Every device starts out running.
  int start(Map<String, String> devices, {String source = ''}) {
    final run = ScenarioRun(
      id: _nextId++,
      startedAt: DateTime.now(),
      source: source,
      devices: [
        for (final MapEntry(:key, :value) in devices.entries)
          ScenarioDeviceRun(deviceId: key, name: value),
      ],
    );
    emit([run, ...stateValue.take(_keep - 1)]);
    return run.id;
  }

  /// Appends a Maestro output [line] to run [id]'s live log, and to
  /// [deviceId]'s own log when given.
  void appendLine(int id, String line, {String? deviceId}) => emit([
    for (final r in stateValue)
      if (r.id != id) r else _withLine(r, line, deviceId),
  ]);

  /// [run] with [line] on its log (tagged with the device's name when the
  /// run has several) and on [deviceId]'s own log.
  ScenarioRun _withLine(ScenarioRun run, String line, String? deviceId) {
    final device = run.devices.where((d) => d.deviceId == deviceId);
    final tagged =
        device.isNotEmpty && run.devices.length > 1 && line.isNotEmpty
        ? '[${device.first.name}] $line'
        : line;
    return ScenarioRun(
      id: run.id,
      startedAt: run.startedAt,
      source: run.source,
      lines: [...run.lines, tagged].takeLast(_maxLines),
      devices: [
        for (final d in run.devices)
          if (d.deviceId == deviceId)
            d.copyWith(lines: [...d.lines, line].takeLast(_maxLines))
          else
            d,
      ],
    );
  }

  /// Records that top-level command [step] finished on [deviceId] in run
  /// [id]; a failed one is remembered as the device's failed step.
  void stepDone(int id, String deviceId, int step, {required bool passed}) =>
      _updateDevice(
        id,
        deviceId,
        (d) => d.copyWith(
          stepsDone: step + 1,
          failedStep: passed ? null : d.failedStep ?? step,
        ),
      );

  void _updateDevice(
    int id,
    String deviceId,
    ScenarioDeviceRun Function(ScenarioDeviceRun) update,
  ) => emit([
    for (final r in stateValue)
      if (r.id != id)
        r
      else
        ScenarioRun(
          id: r.id,
          startedAt: r.startedAt,
          source: r.source,
          lines: r.lines,
          devices: [
            for (final d in r.devices)
              if (d.deviceId == deviceId) update(d) else d,
          ],
        ),
  ]);

  /// Sets [deviceId]'s outcome in run [id].
  void setDevice(
    int id,
    String deviceId, {
    required ScenarioStatus status,
    int? seconds,
    String? error,
  }) => _updateDevice(
    id,
    deviceId,
    (d) => d.copyWith(status: status, seconds: seconds, error: error),
  );

  /// Runs [flow] on [devices] (id → name) with [maestro], recording it as a
  /// new run: live output (prefixed by device name when there are several),
  /// each device's steps, then its outcome. Devices a stop cut short end as
  /// stopped; any error fails the devices still running and is rethrown.
  Future<MaestroRunResult> runFlow(
    MaestroRunner maestro,
    String flow,
    Map<String, String> devices,
  ) async {
    final id = start(devices, source: flow);
    try {
      final result = await maestro.run(
        flowYaml: flow,
        deviceIds: devices.keys.toList(),
        onLine: (device, line) => appendLine(id, line, deviceId: device),
        onStep: (device, step, {required passed}) =>
            stepDone(id, device, step, passed: passed),
      );
      for (final device in devices.keys) {
        final r = result.deviceFor(device);
        setDevice(
          id,
          device,
          status: r == null
              ? (isStopped(id) ? ScenarioStatus.stopped : ScenarioStatus.failed)
              : (r.passed ? ScenarioStatus.ok : ScenarioStatus.failed),
          seconds: r?.seconds,
          error: r?.error ?? (isStopped(id) ? null : 'No result from Maestro'),
        );
      }
      return result;
    } catch (e) {
      failAll(id, '$e');
      rethrow;
    }
  }

  /// Marks every still-running device of run [id] as failed with [error]
  /// (e.g. Maestro missing, or the process died before reporting).
  void failAll(int id, String error) => emit([
    for (final r in stateValue)
      if (r.id != id)
        r
      else
        ScenarioRun(
          id: r.id,
          startedAt: r.startedAt,
          source: r.source,
          lines: r.lines,
          devices: [
            for (final d in r.devices)
              if (d.status == ScenarioStatus.running)
                d.copyWith(status: ScenarioStatus.failed, error: error)
              else
                d,
          ],
        ),
  ]);
}

extension<T> on List<T> {
  List<T> takeLast(int n) => length <= n ? this : sublist(length - n);
}
