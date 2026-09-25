import 'dart:convert';
import 'dart:io';

import 'package:simutil/models/device_state.dart';
import 'package:simutil/models/device_type.dart';
import 'package:simutil/services/ios_device_service.dart';
import 'package:test/test.dart';

import 'fake_command_exec.dart';

void main() {
  group('extractPlatformName', () {
    test('formats an iOS runtime key', () {
      expect(
        IOSDeviceService.extractPlatformName(
          'com.apple.CoreSimulator.SimRuntime.iOS-17-2',
        ),
        'iOS 17.2',
      );
    });

    test('formats a watchOS runtime key', () {
      expect(
        IOSDeviceService.extractPlatformName(
          'com.apple.CoreSimulator.SimRuntime.watchOS-10-0',
        ),
        'watchOS 10.0',
      );
    });
  });

  group('parseSimulators', () {
    test('keeps available devices and maps their state/platform', () {
      final jsonStr = jsonEncode({
        'devices': {
          'com.apple.CoreSimulator.SimRuntime.iOS-17-2': [
            {
              'udid': 'udid-1',
              'name': 'iPhone 15',
              'state': 'Booted',
              'isAvailable': true,
            },
            {
              'udid': 'udid-2',
              'name': 'iPhone 15 Pro',
              'state': 'Shutdown',
              'isAvailable': false,
            },
          ],
        },
      });

      final devices = IOSDeviceService.parseSimulators(jsonStr);

      expect(devices, hasLength(1));
      expect(devices.single.id, 'udid-1');
      expect(devices.single.name, 'iPhone 15');
      expect(devices.single.platform, 'iOS 17.2');
      expect(devices.single.state, DeviceState.booted);
      expect(devices.single.type, DeviceType.simulator);
    });

    test('returns empty list when no devices key present', () {
      expect(IOSDeviceService.parseSimulators('{}'), isEmpty);
    });
  });

  group('parsePhysicalDevices', () {
    test('keeps connected devices and skips disconnected ones', () {
      final json = {
        'result': {
          'devices': [
            {
              'identifier': 'id-connected',
              'deviceProperties': {
                'name': 'My iPhone',
                'osVersionNumber': '17.2',
              },
              'hardwareProperties': {'reality': 'physical'},
              'connectionProperties': {'tunnelState': 'connected'},
            },
            {
              'identifier': 'id-disconnected',
              'deviceProperties': {
                'name': 'Old iPhone',
                'osVersionNumber': '16.0',
              },
              'connectionProperties': {'tunnelState': 'disconnected'},
            },
          ],
        },
      };

      final devices = IOSDeviceService.parsePhysicalDevices(json);

      expect(devices, hasLength(1));
      expect(devices.single.id, 'id-connected');
      expect(devices.single.name, 'My iPhone');
      expect(devices.single.platform, 'iOS 17.2');
      expect(devices.single.type, DeviceType.physical);
      expect(devices.single.state, DeviceState.booted);
    });

    test('drops booted simulators that devicectl reports as connected', () {
      final json = {
        'result': {
          'devices': [
            {
              'identifier': 'sim-booted',
              'deviceProperties': {
                'name': 'iPhone 17',
                'osVersionNumber': '27.0',
              },
              'hardwareProperties': {'reality': 'simulated'},
              'connectionProperties': {'tunnelState': 'connected'},
            },
            {
              'identifier': 'sim-properties',
              'deviceProperties': {
                'name': 'iPhone 18 Pro',
                'osVersionNumber': '27.0',
              },
              'properties': {
                'hardware': {'reality': 'simulated'},
              },
              'connectionProperties': {'tunnelState': 'connected'},
            },
          ],
        },
      };

      expect(IOSDeviceService.parsePhysicalDevices(json), isEmpty);
    });

    test('returns empty list for missing result', () {
      expect(IOSDeviceService.parsePhysicalDevices({}), isEmpty);
    });
  });

  group('resolveSimulatorAppPath', () {
    const developerPath = '/Applications/Xcode.app/Contents/Developer';
    const deviceHub =
        '/Applications/Xcode.app/Contents/Applications/DeviceHub.app';
    const simulator =
        '/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app';

    test('prefers DeviceHub.app when it exists', () {
      expect(
        IOSDeviceService.resolveSimulatorAppPath(
          developerPath: developerPath,
          exists: (path) => path == deviceHub || path == simulator,
        ),
        deviceHub,
      );
    });

    test('falls back to Simulator.app when DeviceHub is absent', () {
      expect(
        IOSDeviceService.resolveSimulatorAppPath(
          developerPath: developerPath,
          exists: (path) => path == simulator,
        ),
        simulator,
      );
    });

    test('returns null when neither app exists', () {
      expect(
        IOSDeviceService.resolveSimulatorAppPath(
          developerPath: developerPath,
          exists: (_) => false,
        ),
        isNull,
      );
    });

    test('returns null when xcode-select path is missing', () {
      expect(
        IOSDeviceService.resolveSimulatorAppPath(
          developerPath: null,
          exists: (_) => true,
        ),
        isNull,
      );
      expect(
        IOSDeviceService.resolveSimulatorAppPath(
          developerPath: '',
          exists: (_) => true,
        ),
        isNull,
      );
    });
  });

  group('openSimulatorApp', () {
    const developerPath = '/Applications/Xcode.app/Contents/Developer\n';

    FakeCommandExec exec({
      String? xcodeSelectStdout,
      bool xcodeSelectOk = true,
    }) {
      return FakeCommandExec((command, _) {
        if (command == '/usr/bin/xcode-select') {
          if (!xcodeSelectOk) return FakeCommandExec.fail('xcode-select');
          return FakeCommandExec.ok(xcodeSelectStdout ?? developerPath);
        }
        if (command == 'open') return FakeCommandExec.ok();
        return FakeCommandExec.fail('unexpected $command');
      });
    }

    test(
      'opens DeviceHub.app without CurrentDeviceUDID on Xcode 27+',
      () async {
        final commandExec = exec();
        final service = IOSDeviceService(
          commandExec,
          pathExists: (path) => path.endsWith('DeviceHub.app'),
        );

        await service.openSimulatorApp('UDID-1');

        expect(commandExec.calls.last.command, 'open');
        expect(commandExec.calls.last.arguments, [
          '-a',
          '/Applications/Xcode.app/Contents/Applications/DeviceHub.app',
        ]);
      },
    );

    test(
      'opens Simulator.app with CurrentDeviceUDID when DeviceHub is absent',
      () async {
        final commandExec = exec();
        final service = IOSDeviceService(
          commandExec,
          pathExists: (path) => path.endsWith('Simulator.app'),
        );

        await service.openSimulatorApp('UDID-1');

        expect(commandExec.calls.last.arguments, [
          '-a',
          '/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app',
          '--args',
          '-CurrentDeviceUDID',
          'UDID-1',
        ]);
      },
    );

    test(
      'falls back to the Simulator app name when xcode-select fails',
      () async {
        final commandExec = exec(xcodeSelectOk: false);
        final service = IOSDeviceService(commandExec, pathExists: (_) => false);

        await service.openSimulatorApp('UDID-1');

        expect(commandExec.calls.last.arguments, [
          '-a',
          'Simulator',
          '--args',
          '-CurrentDeviceUDID',
          'UDID-1',
        ]);
      },
    );
  });

  group('platform guards', () {
    test('non-macOS returns empty/false without invoking commands', () async {
      // These guards short-circuit before touching CommandExec on non-macOS.
      final exec = FakeCommandExec((_, _) {
        throw StateError('command should not run on non-macOS');
      });
      final service = IOSDeviceService(exec);

      if (Platform.isMacOS) {
        // On macOS the guard does not apply; nothing to assert here.
        return;
      }

      expect(await service.getSimulators(), isEmpty);
      expect(await service.getPhysicalDevices(), isEmpty);
      expect(await service.isAvailable(), isFalse);
      expect(exec.calls, isEmpty);
    });
  });
}
