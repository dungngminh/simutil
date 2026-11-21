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
}
