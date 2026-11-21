import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/scenarios/scenario_runs_cubit.dart';

ScenarioRun _run(List<ScenarioStatus> statuses) => ScenarioRun(
  id: 0,
  startedAt: DateTime(2026),
  devices: [
    for (final (i, s) in statuses.indexed)
      ScenarioDeviceRun(deviceId: '$i', name: 'd$i', status: s),
  ],
);

void main() {
  test('a run is running, failed, stopped or ok, in that order', () {
    const ok = ScenarioStatus.ok, failed = ScenarioStatus.failed;
    const stopped = ScenarioStatus.stopped, running = ScenarioStatus.running;
    expect(_run([ok, running]).status, running);
    expect(_run([stopped, failed]).status, failed);
    expect(_run([ok, stopped]).status, stopped);
    expect(_run([ok, ok]).status, ok);
  });

  test('a device places each step before, at or after its progress', () {
    const d = ScenarioDeviceRun(deviceId: 'a', name: 'a', stepsDone: 2);
    expect(d.stepStatus(1), ScenarioStatus.ok);
    expect(d.stepStatus(2), ScenarioStatus.running);
    expect(d.stepStatus(3), isNull);
    final failed = d.copyWith(status: ScenarioStatus.failed, failedStep: 2);
    expect(failed.stepStatus(2), ScenarioStatus.failed);
    expect(failed.stepStatus(3), isNull);
  });

  test('each device keeps its own log; the run log tags lines by name', () {
    final runs = ScenarioRunsCubit();
    final id = runs.start({'a': 'Pixel', 'b': 'iPhone'});
    runs
      ..appendLine(id, 'one', deviceId: 'a')
      ..appendLine(id, '', deviceId: 'b')
      ..stepDone(id, 'a', 0, passed: true)
      ..stepDone(id, 'b', 0, passed: false);
    final run = runs.stateValue.single;
    expect(run.lines, ['[Pixel] one', '']);
    expect(run.devices[0].lines, ['one']);
    expect(run.devices[1].lines, ['']);
    expect(run.devices[0].stepStatus(0), ScenarioStatus.ok);
    expect(run.devices[1].stepStatus(0), ScenarioStatus.failed);
  });

  test('clear forgets finished runs and keeps running ones', () {
    final runs = ScenarioRunsCubit();
    final done = runs.start({'a': 'A'});
    runs.setDevice(done, 'a', status: ScenarioStatus.ok);
    final live = runs.start({'b': 'B'});
    runs.clear();
    expect(runs.stateValue.map((r) => r.id), [live]);
  });
}
