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

    test('returns empty list for missing result', () {
      expect(IOSDeviceService.parsePhysicalDevices({}), isEmpty);
    });
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
