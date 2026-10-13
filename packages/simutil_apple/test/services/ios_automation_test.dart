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
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('built for iPhone and iPad devices'),
        ),
      ),
    );
    expect(exec.calls.map((c) => c.command), ['plutil']);
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
