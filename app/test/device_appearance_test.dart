import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/devices/device_appearance.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_core/testing.dart';

void main() {
  final emulator = testAndroidEmulator(state: DeviceState.booted);
  final simulator = testIosSimulator();

  test('Android reads and switches night mode through adb', () async {
    var night = 'yes';
    final exec = FakeCommandExec((_, args) {
      if (args.length == 7) night = args.last;
      return FakeCommandExec.ok('Night mode: $night\n');
    });
    final appearance = DeviceAppearance(exec, adbPath: () => 'adb');

    expect(await appearance.isDark(emulator), isTrue);
    await appearance.setDark(emulator, dark: false);
    expect(await appearance.isDark(emulator), isFalse);
    // Reads (prefetched on hover) stay out of the interactive slots.
    expect(exec.calls.first.priority, CommandPriority.background);
    expect(exec.calls[1].priority, CommandPriority.interactive);
    expect(exec.calls[1].arguments, [
      '-s',
      emulator.id,
      'shell',
      'cmd',
      'uimode',
      'night',
      'no',
    ]);
  });

  test('an automatic night mode or a failure reads as unknown', () async {
    final auto = DeviceAppearance(
      FakeCommandExec((_, _) => FakeCommandExec.ok('Night mode: auto\n')),
      adbPath: () => 'adb',
    );
    expect(await auto.isDark(emulator), isNull);

    final failing = DeviceAppearance(
      FakeCommandExec((_, _) => FakeCommandExec.fail('device offline')),
      adbPath: () => 'adb',
    );
    expect(await failing.isDark(emulator), isNull);
    await expectLater(
      failing.setDark(emulator, dark: true),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('device offline'),
        ),
      ),
    );
  });

  test('iOS simulators switch through simctl ui appearance', () async {
    final exec = FakeCommandExec((_, args) => FakeCommandExec.ok('dark\n'));
    final appearance = DeviceAppearance(exec, adbPath: () => 'adb');

    expect(await appearance.isDark(simulator), isTrue);
    await appearance.setDark(simulator, dark: false);
    expect(exec.calls.last.command, 'xcrun');
    expect(exec.calls.last.arguments, [
      'simctl',
      'ui',
      simulator.id,
      'appearance',
      'light',
    ]);
  });

  test('physical iPhones and stopped devices are not supported', () async {
    final exec = FakeCommandExec((_, _) => FakeCommandExec.ok('dark'));
    final appearance = DeviceAppearance(exec, adbPath: () => 'adb');

    expect(await appearance.isDark(testIosPhone()), isNull);
    expect(
      await appearance.isDark(testIosSimulator(state: DeviceState.shutdown)),
      isNull,
    );
    expect(exec.calls, isEmpty);
  });
}
