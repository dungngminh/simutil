import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_app/src/settings/device_settings_cubit.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_app/src/ui/shared/device_actions.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_core/testing.dart';

void main() {
  test('a restart handed over by a device window reopens it there', () async {
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
    final devices = DevicesCubit(
      android: android,
      ios: FakeDeviceService(),
      loadIos: false,
      pollInterval: Duration.zero,
    );
    final streams = StreamsCubit((_) => throw StateError('not in the grid'));
    final reopened = <String>[];
    final device = Device.android(
      id: 'emulator-5554',
      name: 'Pixel',
      state: DeviceState.booted,
      type: DeviceType.simulator,
    );

    await DeviceCommands.forWindow(
      device: device,
      settings: const DeviceSettings(),
      devices: devices,
      streams: streams,
      globalHeadless: false,
      reopenInWindow: (d) => reopened.add(d.name),
    ).restart();

    expect(android.shutdown, ['emulator-5554']);
    expect(android.launched.single.deviceId, 'Pixel');
    expect(reopened, ['Pixel']);
    // Not queued for the main window's grid.
    expect(streams.stateValue.booting, isEmpty);
    await streams.close();
    await devices.close();
  });
}
