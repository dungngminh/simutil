import 'package:simutil/models/device_state.dart';
import 'package:test/test.dart';

void main() {
  test('label maps each value to a display string', () {
    expect(DeviceState.shutdown.label, 'Shutdown');
    expect(DeviceState.booted.label, 'Booted');
    expect(DeviceState.booting.label, 'Booting');
  });

  group('isRunning', () {
    test('booted and booting are running', () {
      expect(DeviceState.booted.isRunning, isTrue);
      expect(DeviceState.booting.isRunning, isTrue);
    });

    test('shutdown is not running', () {
      expect(DeviceState.shutdown.isRunning, isFalse);
    });
  });

  group('fromString', () {
    test('booted and running map to booted', () {
      expect(DeviceState.fromString('booted'), DeviceState.booted);
      expect(DeviceState.fromString('running'), DeviceState.booted);
    });

    test('booting maps to booting', () {
      expect(DeviceState.fromString('booting'), DeviceState.booting);
    });

    test('is case-insensitive', () {
      expect(DeviceState.fromString('BOOTED'), DeviceState.booted);
      expect(DeviceState.fromString('Running'), DeviceState.booted);
    });

    test('unknown values default to shutdown', () {
      expect(DeviceState.fromString('Shutdown'), DeviceState.shutdown);
      expect(DeviceState.fromString('whatever'), DeviceState.shutdown);
      expect(DeviceState.fromString(''), DeviceState.shutdown);
    });
  });
}
