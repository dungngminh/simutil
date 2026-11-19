import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_core/testing.dart';

/// Reads its list when a load starts and answers once [gate] opens, like
/// adb answering for the state it saw when asked.
class _SlowService extends FakeDeviceService {
  _SlowService({super.simulators});

  Completer<void>? gate;
  int loads = 0;

  @override
  Future<List<Device>> getSimulators() async {
    loads++;
    final seen = simulators;
    if (gate case final gate?) await gate.future;
    return seen;
  }
}

/// A launch that fails, as a refused `emulator` start does.
class _FailingLaunch extends FakeDeviceService {
  _FailingLaunch({super.simulators});

  @override
  Future<void> launchDevice({
    required String deviceId,
    List<String> additionalArgs = const [],
    bool headless = false,
  }) async => throw StateError('AVD is already running');
}

void main() {
  Device emulator(String id, DeviceState state) => Device.android(
    id: id,
    name: id,
    state: state,
    type: DeviceType.simulator,
  );

  test('refresh loads Android and iOS lists', () async {
    final cubit = DevicesCubit(
      android: FakeDeviceService(
        simulators: [emulator('pixel', DeviceState.shutdown)],
      ),
      ios: FakeDeviceService(
        simulators: [
          Device.ios(
            id: 'u1',
            name: 'iPhone',
            state: DeviceState.booted,
            type: DeviceType.simulator,
          ),
        ],
      ),
      loadIos: true,
    );

    await cubit.refresh();

    expect(cubit.stateValue.androidEmulators.single.id, 'pixel');
    expect(cubit.stateValue.iosSimulators.single.id, 'u1');
    expect(cubit.stateValue.loading, isFalse);
    await cubit.close();
  });

  test('shutdown announces progress as a notice, not as state', () async {
    final cubit = DevicesCubit(
      // The fake never changes state: don't wait for it.
      launchTimeout: Duration.zero,
      stopTimeout: Duration.zero,
      android: FakeDeviceService(),
      ios: FakeDeviceService(),
      loadIos: false,
    );
    final notices = <DeviceNotice>[];
    cubit.notices.listen(notices.add);

    await cubit.shutdown(emulator('pixel', DeviceState.booted));

    expect(notices, [
      (text: 'Stopping pixel…', kind: DeviceNoticeKind.info, deviceId: null),
    ]);
    expect(cubit.stateValue.busy, isEmpty);
    await cubit.close();
  });

  test('launch boots only stopped emulators', () async {
    final android = FakeDeviceService();
    final cubit = DevicesCubit(
      // The fake never changes state: don't wait for it.
      launchTimeout: Duration.zero,
      stopTimeout: Duration.zero,
      android: android,
      ios: FakeDeviceService(),
      loadIos: false,
    );

    await cubit.launch(emulator('booted', DeviceState.booted));
    await cubit.launch(emulator('off', DeviceState.shutdown));

    expect(android.launched.map((c) => c.deviceId), ['off']);
    await cubit.close();
  });

  test('launch passes Android launch options', () async {
    final android = FakeDeviceService();
    final cubit = DevicesCubit(
      // The fake never changes state: don't wait for it.
      launchTimeout: Duration.zero,
      stopTimeout: Duration.zero,
      android: android,
      ios: FakeDeviceService(),
      loadIos: false,
    );

    await cubit.launch(
      emulator('off', DeviceState.shutdown),
      coldBoot: true,
      noAudio: true,
    );

    expect(android.launched.single.args, ['-no-snapshot-load', '-no-audio']);
    await cubit.close();
  });

  test('restart stops, waits for the AVD to stop, then boots it', () async {
    final android = FakeDeviceService(
      simulators: [
        Device.android(
          id: 'Pixel',
          name: 'Pixel',
          state: DeviceState.shutdown,
          type: DeviceType.simulator,
        ),
      ],
    );
    final cubit = DevicesCubit(
      // The fake never changes state: don't wait for it.
      launchTimeout: Duration.zero,
      stopTimeout: Duration.zero,
      android: android,
      ios: FakeDeviceService(),
      loadIos: false,
      pollInterval: Duration.zero,
    );

    await cubit.restart(
      Device.android(
        id: 'emulator-5554',
        name: 'Pixel',
        state: DeviceState.booted,
        type: DeviceType.simulator,
      ),
      headless: true,
    );

    expect(android.shutdown, ['emulator-5554']);
    expect(android.launched.single.deviceId, 'Pixel');
    expect(android.launched.single.headless, isTrue);
    await cubit.close();
  });

  test('delete removes only shut-down emulators', () async {
    final android = FakeDeviceService();
    final cubit = DevicesCubit(
      android: android,
      ios: FakeDeviceService(),
      loadIos: false,
    );

    await cubit.delete(emulator('running', DeviceState.booted));
    await cubit.delete(emulator('off', DeviceState.shutdown));

    expect(android.deleted, ['off']);
    await cubit.close();
  });

  group('wipe and delete notices', () {
    Future<List<DeviceNotice>> run(
      FakeDeviceService android,
      Future<void> Function(DevicesCubit cubit, Device device) action,
    ) async {
      final cubit = DevicesCubit(
        android: android,
        ios: FakeDeviceService(),
        loadIos: false,
      );
      final notices = <DeviceNotice>[];
      cubit.notices.listen(notices.add);
      await action(cubit, emulator('pixel', DeviceState.shutdown));
      await cubit.close();
      return notices;
    }

    test('delete shows loading, then success', () async {
      expect(await run(FakeDeviceService(), (c, d) => c.delete(d)), [
        (
          text: 'Deleting pixel…',
          kind: DeviceNoticeKind.busy,
          deviceId: 'pixel',
        ),
        (
          text: 'Deleted pixel',
          kind: DeviceNoticeKind.success,
          deviceId: 'pixel',
        ),
      ]);
    });

    test('wipe shows loading, then success', () async {
      expect(await run(FakeDeviceService(), (c, d) => c.wipeData(d)), [
        (text: 'Wiping pixel…', kind: DeviceNoticeKind.busy, deviceId: 'pixel'),
        (
          text: 'Wiped pixel',
          kind: DeviceNoticeKind.success,
          deviceId: 'pixel',
        ),
      ]);
    });

    test('a failure ends in an error', () async {
      final failing = _FailingDeviceService();
      expect((await run(failing, (c, d) => c.delete(d))).last, (
        text: 'Failed to delete pixel',
        kind: DeviceNoticeKind.error,
        deviceId: 'pixel',
      ));
      expect((await run(failing, (c, d) => c.wipeData(d))).last, (
        text: 'Failed to wipe pixel',
        kind: DeviceNoticeKind.error,
        deviceId: 'pixel',
      ));
    });
  });

  test('refresh is single-flight', () async {
    final android = _SlowService(
      simulators: [emulator('pixel', DeviceState.shutdown)],
    );
    final cubit = DevicesCubit(
      android: android,
      ios: FakeDeviceService(),
      loadIos: false,
    );

    final first = cubit.refresh(silent: true);
    // Calls during a reload share one more reload after it, never more.
    final second = cubit.refresh();
    final third = cubit.refresh(silent: true);
    expect(identical(second, third), isTrue);
    await first;
    await second;
    expect(android.loads, 2);
    expect(cubit.stateValue.loading, isFalse);
    expect(cubit.stateValue.androidEmulators.single.id, 'pixel');
    await cubit.close();
  });

  test('reloads when a platform reports a device change', () async {
    final android = FakeDeviceService();
    final cubit = DevicesCubit(
      android: android,
      ios: FakeDeviceService(),
      loadIos: false,
    )..start();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.stateValue.androidEmulators, isEmpty);

    android
      ..simulators = [emulator('pixel', DeviceState.booted)]
      ..emitDeviceChange();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(cubit.stateValue.androidEmulators.single.id, 'pixel');
    await cubit.close();
  });
  test('a change reported during a reload reloads again', () async {
    final android = _SlowService(
      simulators: [emulator('Pixel', DeviceState.shutdown)],
    )..gate = Completer();
    final cubit = DevicesCubit(android: android, ios: FakeDeviceService());

    // A reload is running and has read the list before the boot.
    final first = cubit.refresh(silent: true);
    await Future<void>.delayed(Duration.zero);
    // adb reports the boot meanwhile.
    android.simulators = [
      Device.android(
        id: 'emulator-5554',
        name: 'Pixel',
        state: DeviceState.booted,
        type: DeviceType.simulator,
      ),
    ];
    final second = cubit.refresh(silent: true);
    final gate = android.gate!;
    android.gate = null;
    gate.complete();
    await first;
    await second;

    expect(cubit.stateValue.androidEmulators.single.state, DeviceState.booted);
    expect(android.loads, 2);
    await cubit.close();
  });

  test('launch stays busy until the emulator shows as booted', () async {
    final android = FakeDeviceService(
      simulators: [emulator('Pixel', DeviceState.shutdown)],
    );
    final cubit = DevicesCubit(
      android: android,
      ios: FakeDeviceService(),
      pollInterval: const Duration(milliseconds: 50),
    );

    final launching = cubit.launch(emulator('Pixel', DeviceState.shutdown));
    // Past the old fixed settle delay: still starting, so no Start button.
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    expect(cubit.stateValue.busy, contains('Pixel'));

    android.simulators = [
      Device.android(
        id: 'emulator-5554',
        name: 'Pixel',
        state: DeviceState.booted,
        type: DeviceType.simulator,
      ),
    ];
    await launching.timeout(const Duration(seconds: 5));

    expect(cubit.stateValue.busy, isEmpty);
    expect(cubit.stateValue.androidEmulators.single.state, DeviceState.booted);
    await cubit.close();
  });

  test('a failed launch stops waiting for the boot', () async {
    final cubit = DevicesCubit(
      android: _FailingLaunch(
        simulators: [emulator('Pixel', DeviceState.shutdown)],
      ),
      ios: FakeDeviceService(),
      pollInterval: const Duration(milliseconds: 50),
    );
    final errors = <String>[];
    cubit.notices
        .where((n) => n.kind == DeviceNoticeKind.error)
        .listen((n) => errors.add(n.text));

    await cubit
        .launch(emulator('Pixel', DeviceState.shutdown))
        .timeout(const Duration(seconds: 5));

    expect(cubit.stateValue.busy, isEmpty);
    expect(errors.single, contains('AVD is already running'));
    await cubit.close();
  });

  test('shutdown stays busy until the emulator is gone', () async {
    final android = FakeDeviceService(
      simulators: [
        Device.android(
          id: 'emulator-5554',
          name: 'Pixel',
          state: DeviceState.booted,
          type: DeviceType.simulator,
        ),
      ],
    );
    final cubit = DevicesCubit(
      android: android,
      ios: FakeDeviceService(),
      pollInterval: const Duration(milliseconds: 50),
    );
    await cubit.refresh();

    final stopping = cubit.shutdown(android.simulators.single);
    // Past the old fixed settle delay: the emulator still runs.
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    expect(cubit.stateValue.busy, contains('emulator-5554'));

    android.simulators = [emulator('Pixel', DeviceState.shutdown)];
    await stopping.timeout(const Duration(seconds: 5));

    expect(cubit.stateValue.busy, isEmpty);
    expect(
      cubit.stateValue.androidEmulators.single.state,
      DeviceState.shutdown,
    );
    await cubit.close();
  });
}

class _FailingDeviceService extends FakeDeviceService {
  @override
  Future<bool> deleteSimulator({required String deviceId}) async => false;

  @override
  Future<bool> wipeData({required String deviceId}) async => false;
}
