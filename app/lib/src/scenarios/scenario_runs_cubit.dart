import 'package:bloc_signals/bloc_signals.dart';
import 'package:equatable/equatable.dart';

/// Where a device, a step or a whole run stands; [skipped] is a step whose
/// condition (if_visible / if_not_visible) did not hold.
enum ScenarioStatus { pending, running, ok, failed, skipped }

/// One device's progress through a scenario.
final class ScenarioDeviceRun extends Equatable {
  const ScenarioDeviceRun({
    required this.deviceId,
    required this.name,
    this.status = ScenarioStatus.running,
    this.step = 0,
    this.ms,
    this.error,
    this.skipped = const [],
  });

  final String deviceId;
  final String name;
  final ScenarioStatus status;

  /// Steps finished so far; when failed, the step that failed.
  final int step;

  /// Run time once finished.
  final int? ms;
  final String? error;

  /// Steps skipped because their condition did not hold.
  final List<int> skipped;

  ScenarioDeviceRun copyWith({
    ScenarioStatus? status,
    int? step,
    int? ms,
    String? error,
    List<int>? skipped,
  }) => ScenarioDeviceRun(
    deviceId: deviceId,
    name: name,
    status: status ?? this.status,
    step: step ?? this.step,
    ms: ms ?? this.ms,
    error: error ?? this.error,
    skipped: skipped ?? this.skipped,
  );

  @override
  List<Object?> get props => [deviceId, name, status, step, ms, error, skipped];
}

/// One `run_scenario` call across its devices.
final class ScenarioRun extends Equatable {
  const ScenarioRun({
    required this.id,
    required this.startedAt,
    required this.steps,
    required this.devices,
    this.source = '',
    this.lines = const [],
  });

  final int id;
  final DateTime startedAt;

  /// Each step, described for people (`tap "month"`), in order.
  final List<String> steps;
  final List<ScenarioDeviceRun> devices;

  /// The scenario's YAML, as written in the editor or generated from an
  /// agent's steps.
  final String source;

  /// First line (0-based) of each step in [source]; empty when unknown.
  final List<int> lines;

  ScenarioStatus get status =>
      devices.any((d) => d.status == ScenarioStatus.running)
      ? ScenarioStatus.running
      : devices.every((d) => d.status == ScenarioStatus.ok)
      ? ScenarioStatus.ok
      : ScenarioStatus.failed;

  /// Step [i] across devices: failed when one failed on it, running while
  /// one is on it, ok once every device still going got past it.
  ScenarioStatus stepStatus(int i) {
    final each = [
      for (final d in devices)
        if (d.skipped.contains(i))
          ScenarioStatus.skipped
        else if (i < d.step)
          ScenarioStatus.ok
        else if (i == d.step && d.status != ScenarioStatus.ok)
          d.status
        else
          // Not reached yet, or skipped after the device failed earlier.
          d.status == ScenarioStatus.failed ? null : ScenarioStatus.pending,
    ];
    if (each.contains(ScenarioStatus.failed)) return ScenarioStatus.failed;
    if (each.contains(ScenarioStatus.running)) return ScenarioStatus.running;
    if (!each.contains(ScenarioStatus.pending)) {
      if (each.contains(ScenarioStatus.ok)) return ScenarioStatus.ok;
      if (each.contains(ScenarioStatus.skipped)) return ScenarioStatus.skipped;
    }
    return ScenarioStatus.pending;
  }

  /// Devices that failed on step [i], with their errors.
  List<(String, String)> stepErrors(int i) => [
    for (final d in devices)
      if (d.status == ScenarioStatus.failed && d.step == i)
        (d.name, d.error ?? 'failed'),
  ];

  /// How many devices got past step [i].
  int passed(int i) => devices.where((d) => d.step > i).length;

  @override
  List<Object?> get props => [id, startedAt, steps, devices, source, lines];
}

/// Scenario runs, newest first, for the scenarios panel.
class ScenarioRunsCubit extends CubitSignal<List<ScenarioRun>> {
  ScenarioRunsCubit() : super(initialState: const []);

  /// ponytail: keeps the last [_keep] runs in memory; persist if users need
  /// history across launches.
  static const _keep = 20;
  var _nextId = 0;
  final _stopped = <int>{};

  /// Asks run [id] to stop; its devices stop at their next check.
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

  /// Records a run starting on [devices] (id → name); returns its id.
  int start(
    Map<String, String> devices,
    List<String> steps, {
    String source = '',
    List<int> lines = const [],
  }) {
    final run = ScenarioRun(
      id: _nextId++,
      startedAt: DateTime.now(),
      steps: List.unmodifiable(steps),
      source: source,
      lines: List.unmodifiable(lines),
      devices: [
        for (final MapEntry(:key, :value) in devices.entries)
          ScenarioDeviceRun(deviceId: key, name: value),
      ],
    );
    emit([run, ...stateValue.take(_keep - 1)]);
    return run.id;
  }

  /// [deviceId] finished [step] steps of run [id].
  void progress(int id, String deviceId, int step) =>
      _update(id, deviceId, (d) => d.copyWith(step: step));

  /// [deviceId] skipped [step] of run [id] (its condition did not hold).
  void skip(int id, String deviceId, int step) => _update(
    id,
    deviceId,
    (d) => d.copyWith(skipped: [...d.skipped, step], step: step + 1),
  );

  /// [deviceId] finished run [id]; [error] marks it failed.
  void finish(int id, String deviceId, {required int ms, String? error}) =>
      _update(
        id,
        deviceId,
        (d) => d.copyWith(
          status: error == null ? ScenarioStatus.ok : ScenarioStatus.failed,
          ms: ms,
          error: error,
        ),
      );

  void _update(
    int id,
    String deviceId,
    ScenarioDeviceRun Function(ScenarioDeviceRun) change,
  ) => emit([
    for (final r in stateValue)
      if (r.id != id)
        r
      else
        ScenarioRun(
          id: r.id,
          startedAt: r.startedAt,
          steps: r.steps,
          source: r.source,
          lines: r.lines,
          devices: [
            for (final d in r.devices)
              if (d.deviceId == deviceId) change(d) else d,
          ],
        ),
  ]);
}
