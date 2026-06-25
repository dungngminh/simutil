import 'package:simutil/models/device.dart';
import 'package:simutil/models/device_os.dart';
import 'package:simutil/models/device_state.dart';
import 'package:simutil/models/device_type.dart';
import 'package:test/test.dart';

void main() {
  group('Device.android', () {
    test('sets Android platform and os', () {
      final device = Device.android(
        id: 'emulator-5554',
        name: 'Pixel 7',
        state: DeviceState.booted,
        type: DeviceType.simulator,
      );

      expect(device.id, 'emulator-5554');
      expect(device.name, 'Pixel 7');
      expect(device.os, DeviceOs.android);
      expect(device.platform, 'Android');
      expect(device.state, DeviceState.booted);
      expect(device.type, DeviceType.simulator);
    });
  });

  group('Device.ios', () {
    test('defaults platform to iOS when not provided', () {
      final device = Device.ios(
        id: 'sim-1',
        name: 'iPhone 15',
        state: DeviceState.shutdown,
        type: DeviceType.simulator,
      );

      expect(device.os, DeviceOs.ios);
      expect(device.platform, 'iOS');
    });

    test('uses provided platform', () {
      final device = Device.ios(
        id: 'sim-1',
        name: 'iPhone 15',
        platform: 'iOS 17.2',
        state: DeviceState.booted,
        type: DeviceType.physical,
      );

      expect(device.platform, 'iOS 17.2');
    });
  });

  group('isRunning', () {
    test('mirrors the device state', () {
      final booted = Device.android(
        id: 'a',
        name: 'a',
        state: DeviceState.booted,
        type: DeviceType.simulator,
      );
      final shutdown = booted.copyWith(state: DeviceState.shutdown);

      expect(booted.isRunning, isTrue);
      expect(shutdown.isRunning, isFalse);
    });
  });

  group('copyWith', () {
    test('overrides only the given fields', () {
      final device = Device.android(
        id: 'a',
        name: 'Original',
        state: DeviceState.shutdown,
        type: DeviceType.simulator,
      );

      final updated = device.copyWith(
        name: 'Renamed',
        state: DeviceState.booted,
      );

      expect(updated.id, 'a');
      expect(updated.name, 'Renamed');
      expect(updated.state, DeviceState.booted);
      expect(updated.os, DeviceOs.android);
      expect(updated.type, DeviceType.simulator);
    });
  });

  group('toJson / fromJson', () {
    test('toJson emits all fields', () {
      final device = Device.android(
        id: 'emulator-5554',
        name: 'Pixel 7',
        state: DeviceState.booted,
        type: DeviceType.simulator,
      );

      expect(device.toJson(), {
        'id': 'emulator-5554',
        'name': 'Pixel 7',
        'os': 'android',
        'platform': 'Android',
        'state': 'Booted',
        'type': 'simulator',
      });
    });

    test('fromJson parses os, type and state independently', () {
      final device = Device.fromJson({
        'id': 'sim-1',
        'name': 'iPhone 15',
        'os': 'ios',
        'platform': 'iOS 17.2',
        'state': 'Booted',
        'type': 'physical',
      });

      expect(device.os, DeviceOs.ios);
      expect(device.type, DeviceType.physical);
      expect(device.state, DeviceState.booted);
      expect(device.platform, 'iOS 17.2');
    });

    test('round-trips through toJson/fromJson', () {
      final device = Device.ios(
        id: 'sim-2',
        name: 'iPad',
        platform: 'iOS 17.0',
        state: DeviceState.shutdown,
        type: DeviceType.simulator,
      );

      final restored = Device.fromJson(device.toJson());

      expect(restored, device);
      expect(restored.type, device.type);
    });

    test('fromJson falls back to Shutdown for missing state', () {
      final device = Device.fromJson({
        'id': 'a',
        'name': 'a',
        'os': 'android',
        'type': 'simulator',
      });

      expect(device.state, DeviceState.shutdown);
      expect(device.platform, '');
    });
  });

  group('equality', () {
    test('equal when id/name/os/platform/state match (ignores type)', () {
      final simulator = Device.android(
        id: 'a',
        name: 'a',
        state: DeviceState.booted,
        type: DeviceType.simulator,
      );
      final physical = Device.android(
        id: 'a',
        name: 'a',
        state: DeviceState.booted,
        type: DeviceType.physical,
      );

      expect(simulator, physical);
      expect(simulator.hashCode, physical.hashCode);
    });

    test('not equal when a compared field differs', () {
      final base = Device.android(
        id: 'a',
        name: 'a',
        state: DeviceState.booted,
        type: DeviceType.simulator,
      );

      expect(base, isNot(base.copyWith(id: 'b')));
      expect(base, isNot(base.copyWith(state: DeviceState.shutdown)));
    });
  });

  test('toString includes name, os and state', () {
    final device = Device.android(
      id: 'a',
      name: 'Pixel',
      state: DeviceState.booted,
      type: DeviceType.simulator,
    );

    expect(device.toString(), contains('Pixel'));
    expect(device.toString(), contains('booted'));
  });
}
