import 'package:bloc_signals/bloc_signals.dart';
import 'package:equatable/equatable.dart';

/// Where a device (or a whole run) stands in a Maestro flow run.
enum ScenarioStatus { running, ok, failed }

/// One device's outcome in a Maestro run (one shard per device).
final class ScenarioDeviceRun extends Equatable {
  const ScenarioDeviceRun({
    required this.deviceId,
    required this.name,
    this.status = ScenarioStatus.running,
    this.seconds,
    this.error,
  });

  final String deviceId;
  final String name;
  final ScenarioStatus status;

  /// How long the flow took on this device, once finished.
  final int? seconds;

  /// Failure message when [status] is failed.
  final String? error;

  ScenarioDeviceRun copyWith({
    ScenarioStatus? status,
    int? seconds,
    String? error,
  }) => ScenarioDeviceRun(
    deviceId: deviceId,
    name: name,
    status: status ?? this.status,
    seconds: seconds ?? this.seconds,
    error: error ?? this.error,
  );

  @override
  List<Object?> get props => [deviceId, name, status, seconds, error];
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
      : devices.every((d) => d.status == ScenarioStatus.ok)
      ? ScenarioStatus.ok
      : ScenarioStatus.failed;

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

  /// Appends a Maestro output [line] to run [id]'s live log.
  void appendLine(int id, String line) => emit([
    for (final r in stateValue)
      if (r.id != id)
        r
      else
        ScenarioRun(
          id: r.id,
          startedAt: r.startedAt,
          source: r.source,
          devices: r.devices,
          lines: [...r.lines, line].takeLast(_maxLines),
        ),
  ]);

  /// Sets [deviceId]'s outcome in run [id].
  void setDevice(
    int id,
    String deviceId, {
    required ScenarioStatus status,
    int? seconds,
    String? error,
  }) => emit([
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
              if (d.deviceId == deviceId)
                d.copyWith(status: status, seconds: seconds, error: error)
              else
                d,
          ],
        ),
  ]);

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
