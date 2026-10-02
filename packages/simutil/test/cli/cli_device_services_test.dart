import 'package:args/command_runner.dart';
import 'package:simutil/simutil.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_core/testing.dart';
import 'package:test/test.dart';

void main() {
  final emulator = testAndroidEmulator();
  final phone = testAndroidPhone(state: DeviceState.shutdown);

  late FakeDeviceService android;
  late CliDeviceServices services;

  setUp(() {
    android = FakeDeviceService(simulators: [emulator], physical: [phone]);
    services = CliDeviceServices(services: {DeviceOs.android: android});
  });

  test('listDevices applies type and running filters', () async {
    expect(await services.listDevices(), [emulator, phone]);
    expect(await services.listDevices(physical: false), [emulator]);
    expect(await services.listDevices(runningOnly: true), [emulator]);
    expect(await services.listDevices(android: false), isEmpty);
  });

  test('launchDevice routes to the device OS service with flags', () async {
    await services.launchDevice(emulator, cold: true, noAudio: true);
    final launch = android.launched.single;
    expect(launch.deviceId, emulator.id);
    expect(launch.args, ['-no-snapshot-load', '-no-audio']);
  });

  test('shutdownDevice routes to the device OS service', () async {
    expect(await services.shutdownDevice(emulator), isTrue);
    expect(android.shutdown, [emulator.id]);
  });

  test('resolveDevice throws UsageException for unknown id', () {
    expect(services.resolveDevice('nope'), throwsA(isA<UsageException>()));
  });
}
