import 'package:simutil_core/simutil_core.dart';

/// Booted Android emulator; override only what the test cares about.
Device testAndroidEmulator({
  String id = 'emulator-5554',
  String name = 'Pixel 7',
  DeviceState state = DeviceState.booted,
}) => Device.android(
  id: id,
  name: name,
  state: state,
  type: DeviceType.simulator,
);

/// Connected physical Android device.
Device testAndroidPhone({
  String id = 'R58M123ABC',
  String name = 'Galaxy S23',
  DeviceState state = DeviceState.booted,
}) =>
    Device.android(id: id, name: name, state: state, type: DeviceType.physical);

/// Booted iOS simulator.
Device testIosSimulator({
  String id = 'sim-1',
  String name = 'iPhone 15',
  DeviceState state = DeviceState.booted,
}) => Device.ios(id: id, name: name, state: state, type: DeviceType.simulator);

/// Connected physical iPhone.
Device testIosPhone({
  String id = '00008110-0001',
  String name = 'iPhone',
  DeviceState state = DeviceState.booted,
}) => Device.ios(id: id, name: name, state: state, type: DeviceType.physical);
