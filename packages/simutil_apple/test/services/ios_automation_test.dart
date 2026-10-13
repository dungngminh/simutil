import 'dart:io';

import 'package:simutil_apple/simutil_apple.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_core/testing.dart';
import 'package:test/test.dart';

final _sim = Device.ios(
  id: 'UDID',
  name: 'iPhone 17',
  state: DeviceState.booted,
  type: DeviceType.simulator,
);

void main() {
  test('install puts an .app on a simulator with simctl', () async {
    final exec = FakeCommandExec(
      (command, _) =>
          FakeCommandExec.ok(command == 'plutil' ? '["iPhoneSimulator"]' : ''),
    );
    await IosAutomation(exec).install(_sim, '/b/Runner.app');
    expect(exec.calls.last.command, 'xcrun');
    expect(exec.calls.last.arguments, [
      'simctl',
      'install',
      'UDID',
      '/b/Runner.app',
    ]);
  });

  test('install unpacks an .ipa, installs its app, then cleans up', () async {
    String? unpacked;
    final exec = FakeCommandExec((command, args) {
      if (command == 'unzip') {
        unpacked = args.last;
        Directory('$unpacked/Payload/Runner.app').createSync(recursive: true);
      }
      return FakeCommandExec.ok();
    });
    await IosAutomation(exec).install(_sim, '/b/Runner.ipa');
    expect(exec.calls.last.arguments, [
      'simctl',
      'install',
      'UDID',
      '$unpacked/Payload/Runner.app',
    ]);
    expect(Directory(unpacked!).existsSync(), isFalse);
  });

  test('install refuses a device build on a simulator', () async {
    final exec = FakeCommandExec(
      (command, _) =>
          FakeCommandExec.ok(command == 'plutil' ? '["iPhoneOS"]' : ''),
    );
    await expectLater(
      IosAutomation(exec).install(_sim, '/b/Runner.app'),
      throwsA(
        isA<DeviceOnlyBuildException>().having(
          (e) => e.bundleName,
          'bundleName',
          'Runner.app',
        ),
      ),
    );
    expect(exec.calls.map((c) => c.command), ['plutil']);
  });

  test('install refuses an App Store build on a device', () async {
    final device = Device.ios(
      id: 'CORE-ID',
      name: 'iPhone',
      state: DeviceState.booted,
      type: DeviceType.physical,
    );
    final exec = FakeCommandExec(
      (command, _) => FakeCommandExec.ok(
        command == 'security' ? '<plist><dict><key>Name</key></dict>' : '',
      ),
    );
    await expectLater(
      IosAutomation(exec).install(device, '/b/Runner.app'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('signed for the App Store'),
        ),
      ),
    );

    exec.handler = (command, _) => FakeCommandExec.ok(
      command == 'security'
          ? '<plist><key>ProvisionedDevices</key></plist>'
          : '',
    );
    await IosAutomation(exec).install(device, '/b/Runner.app');
    expect(exec.calls.last.arguments, [
      'devicectl',
      'device',
      'install',
      'app',
      '--device',
      'CORE-ID',
      '/b/Runner.app',
    ]);
  });

  test('install surfaces the simctl error', () async {
    final exec = FakeCommandExec(
      (_, _) => FakeCommandExec.fail('not built for the simulator'),
    );
    await expectLater(
      IosAutomation(exec).install(_sim, '/b/Runner.app'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'Could not install on iPhone 17: not built for the simulator',
        ),
      ),
    );
  });
}
