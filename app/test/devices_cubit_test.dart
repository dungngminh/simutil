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
}
