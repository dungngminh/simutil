import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/devices/devices_state.dart';
import 'package:simutil_app/src/logging/bloc_log.dart';
import 'package:simutil_app/src/recording/grid_recorder.dart';
import 'package:simutil_app/src/settings/device_settings_cubit.dart';
import 'package:simutil_app/src/settings/view_settings_cubit.dart';
import 'package:simutil_app/src/stream/streams_state.dart';
import 'package:simutil_app/src/ui/recording_toast.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_core/testing.dart';

void main() {
  final pixel = testAndroidEmulator();
  final iphone = testIosSimulator(name: 'iPhone 16');

  test('devices', () {
    final state = DevicesState(
      androidEmulators: [
        pixel,
        testAndroidEmulator(id: 'Pixel_8', state: DeviceState.shutdown),
      ],
      iosSimulators: [iphone],
      busy: {pixel.id},
    );
    expect(describeState(state), '3 devices (2 booted), busy: Pixel 7');
    expect(
      describeState(const DevicesState(loading: true)),
      '0 devices (0 booted), busy: none, refreshing',
    );
  });

  test('streams', () {
    final state = StreamsState([
      StreamEntry(
        device: pixel,
        status: const SessionLive(width: 1080, height: 2400),
        recordingSince: DateTime(2026),
      ),
      StreamEntry(device: iphone, status: const SessionConnecting()),
      StreamEntry(
        device: testAndroidPhone(),
        status: const SessionFailed('scrcpy\nnot found'),
      ),
    ]);
    expect(
      describeState(state),
      '3 open: Pixel 7 live 1080×2400 rec, iPhone 16 connecting, '
      'Galaxy S23 failed (scrcpy not found)',
    );
    expect(describeState(const StreamsState()), 'none open');
  });

  test('view settings', () {
    expect(describeState(const ViewSettings()), 'layout=grid headless=on');
  });

  test('device settings lists only changed devices, non-defaults', () {
    const before = {'Pixel 7': DeviceSettings(), 'iPhone 16': DeviceSettings()};
    const after = {
      'Pixel 7': DeviceSettings(showFrame: false, coldBoot: true),
      'iPhone 16': DeviceSettings(),
    };
    expect(
      describeState(after, previous: before),
      'Pixel 7: frame=off coldBoot=on',
    );
    expect(describeState(before, previous: before), '2 devices');
  });

  test('labels and grid recorder', () {
    expect(blocLabel(GridRecorderCubit()), 'GridRecorder');
    expect(describeState(true), 'recording');
  });

  test('observer skips identical lines', () {
    final lines = <String>[];
    final observer = BlocLogObserver(print: lines.add);
    final cubit = GridRecorderCubit();
    observer
      ..onChange(cubit, const Change(currentState: false, nextState: true))
      ..onChange(cubit, const Change(currentState: false, nextState: true))
      ..onChange(cubit, const Change(currentState: true, nextState: false));
    expect(lines, ['[GridRecorder] recording', '[GridRecorder] idle']);
  });

  test('stream toast changes: new entries and status-kind changes only', () {
    final previous = <String, SessionStatus>{
      pixel.id: const SessionLive(width: 1, height: 1),
      iphone.id: const SessionConnecting(),
    };
    final next = StreamsState([
      StreamEntry(
        device: pixel,
        status: const SessionLive(width: 2, height: 2),
      ),
      StreamEntry(device: iphone, status: const SessionFailed('x')),
      StreamEntry(
        device: testAndroidPhone(),
        status: const SessionConnecting(),
      ),
    ]);
    expect(
      [for (final e in streamToastChanges(previous, next)) e.device.name],
      ['iPhone 16', 'Galaxy S23'],
    );
  });
}
