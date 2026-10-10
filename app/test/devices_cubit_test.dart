import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_core/testing.dart';

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

  test('launch boots only stopped emulators', () async {
    final android = FakeDeviceService();
    final cubit = DevicesCubit(
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

  test('refresh is single-flight', () async {
    final android = FakeDeviceService(
      simulators: [emulator('pixel', DeviceState.shutdown)],
    );
    final cubit = DevicesCubit(
      android: android,
      ios: FakeDeviceService(),
      loadIos: false,
    );

    final first = cubit.refresh(silent: true);
    final second = cubit.refresh();
    expect(identical(first, second), isTrue);
    await first;
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
}
