import 'dart:io';

import 'package:simutil/models/device_state.dart';
import 'package:simutil/models/device_type.dart';
import 'package:simutil/services/android_device_service.dart';
import 'package:test/test.dart';

import 'fake_command_exec.dart';

void main() {
  late Directory sdkDir;
  late String adbPath;
  late String emulatorPath;

  setUp(() {
    sdkDir = Directory.systemTemp.createTempSync('simutil_sdk_');
    adbPath = '${sdkDir.path}/platform-tools/adb';
    emulatorPath = '${sdkDir.path}/emulator/emulator';
    File(adbPath)
      ..createSync(recursive: true)
      ..writeAsStringSync('#!/bin/sh\n');
    File(emulatorPath)
      ..createSync(recursive: true)
      ..writeAsStringSync('#!/bin/sh\n');
  });

  tearDown(() {
    sdkDir.deleteSync(recursive: true);
  });

  AndroidDeviceService service(FakeCommandExec exec) =>
      AndroidDeviceService(exec, androidHomeOverride: sdkDir.path);

  group('paths', () {
    test('resolves adb/emulator paths from the android home override', () {
      final svc = service(FakeCommandExec((_, _) => null));

      expect(svc.getAndroidHome(), sdkDir.path);
      expect(svc.adbPath, adbPath);
      expect(svc.emulatorPath, emulatorPath);
    });

    test('prefers ANDROID_HOME when set', () {
      final svc = AndroidDeviceService(
        FakeCommandExec((_, _) => null),
        environment: {'ANDROID_HOME': '/opt/android-sdk', 'HOME': '/home/test'},
        fileExists: (path) => path == '/opt/android-sdk/platform-tools/adb',
      );

      expect(svc.getAndroidHome(), '/opt/android-sdk');
      expect(svc.adbPath, '/opt/android-sdk/platform-tools/adb');
    });

    test('lets androidHomeOverride win over injected environment values', () {
      final overrideDir = Directory.systemTemp.createTempSync(
        'simutil_override_',
      );
      addTearDown(() => overrideDir.deleteSync(recursive: true));

      final overrideAdb = '${overrideDir.path}/platform-tools/adb';
      File(overrideAdb)
        ..createSync(recursive: true)
        ..writeAsStringSync('#!/bin/sh\n');

      final svc = AndroidDeviceService(
        FakeCommandExec((_, _) => null),
        androidHomeOverride: overrideDir.path,
        environment: {
          'ANDROID_HOME': '/opt/android-sdk',
          'ANDROID_SDK_ROOT': '/opt/android-sdk-root',
          'HOME': '/home/test',
        },
      );

      expect(svc.getAndroidHome(), overrideDir.path);
      expect(svc.adbPath, overrideAdb);
    });

    test('falls back to Linux SDK path when adb exists there', () {
      final svc = AndroidDeviceService(
        FakeCommandExec((_, _) => null),
        environment: {'HOME': '/home/test'},
        fileExists: (path) =>
            path == '/home/test/Android/Sdk/platform-tools/adb',
      );

      expect(svc.getAndroidHome(), '/home/test/Android/Sdk');
      expect(svc.adbPath, '/home/test/Android/Sdk/platform-tools/adb');
    });

    test('falls back to adb on PATH when SDK adb is missing', () {
      final svc = AndroidDeviceService(
        FakeCommandExec((_, _) => null),
        environment: {'HOME': '/home/test'},
        fileExists: (_) => false,
      );

      expect(svc.adbPath, 'adb');
    });
  });

  group('getSimulators', () {
    test('marks running AVDs as booted with their serial', () async {
      final exec = FakeCommandExec((command, args) {
        if (command == emulatorPath && args.contains('-list-avds')) {
          return FakeCommandExec.ok('Pixel_7\nPixel_Tablet\n');
        }
        if (command == adbPath && args.length == 1 && args.first == 'devices') {
          return FakeCommandExec.ok(
            'List of devices attached\nemulator-5554\tdevice\n',
          );
        }
        if (command == adbPath &&
            args.contains('avd') &&
            args.contains('name')) {
          return FakeCommandExec.ok('Pixel_7\nOK\n');
        }
        return null;
      });

      final devices = await service(exec).getSimulators();

      expect(devices, hasLength(2));
      final pixel7 = devices.firstWhere((d) => d.name == 'Pixel_7');
      expect(pixel7.id, 'emulator-5554');
      expect(pixel7.state, DeviceState.booted);
      expect(pixel7.type, DeviceType.simulator);

      final tablet = devices.firstWhere((d) => d.name == 'Pixel_Tablet');
      expect(tablet.id, 'Pixel_Tablet');
      expect(tablet.state, DeviceState.shutdown);
    });

    test('returns empty list when emulator command fails', () async {
      final exec = FakeCommandExec((_, _) => FakeCommandExec.fail());

      expect(await service(exec).getSimulators(), isEmpty);
    });
  });

  group('getPhysicalDevices', () {
    test('parses model and skips emulator entries', () async {
      final exec = FakeCommandExec((command, args) {
        if (command == adbPath) {
          return FakeCommandExec.ok(
            'List of devices attached\n'
            'emulator-5554          device product:sdk model:Emu device:emu\n'
            'ABC123                 device product:bluejay model:Pixel_6a device:bluejay\n',
          );
        }
        return null;
      });

      final devices = await service(exec).getPhysicalDevices();

      expect(devices, hasLength(1));
      expect(devices.single.id, 'ABC123');
      expect(devices.single.name, 'Pixel 6a');
      expect(devices.single.type, DeviceType.physical);
      expect(devices.single.state, DeviceState.booted);
    });

    test('maps non-ready adb states to booting', () async {
      final exec = FakeCommandExec((command, args) {
        if (command == adbPath && args.join(' ') == 'devices -l') {
          return FakeCommandExec.ok(
            'List of devices attached\n'
            'ABC123 device product:foo model:Pixel_8 device:husky\n'
            'DEF456 unauthorized\n'
            'GHI789 offline\n'
            'JKL012 recovery\n'
            'MNO345 sideload\n',
          );
        }
        return null;
      });

      final devices = await service(exec).getPhysicalDevices();

      expect(devices, hasLength(5));
      expect(devices[0].name, 'Pixel 8');
      expect(devices[0].state, DeviceState.booted);
      expect(devices[1].state, DeviceState.booting);
      expect(devices[2].state, DeviceState.booting);
      expect(devices[3].state, DeviceState.booting);
      expect(devices[4].state, DeviceState.booting);
    });

    test('skips adb no permissions rows', () async {
      final exec = FakeCommandExec((command, args) {
        if (command == adbPath && args.join(' ') == 'devices -l') {
          return FakeCommandExec.ok(
            'List of devices attached\n'
            'ABC123                 device product:bluejay model:Pixel_6a device:bluejay\n'
            'usb:1-4.4 no permissions (user in plugdev group; are your udev rules wrong?)\n',
          );
        }
        return null;
      });

      final devices = await service(exec).getPhysicalDevices();

      expect(devices, hasLength(1));
      expect(devices.single.id, 'ABC123');
      expect(devices.single.name, 'Pixel 6a');
    });
  });

  group('connectDevice', () {
    test('reports success on "connected to"', () async {
      final exec = FakeCommandExec(
        (_, _) => FakeCommandExec.ok('connected to 192.168.1.10:5555'),
      );

      final result = await service(exec).connectDevice('192.168.1.10:5555');

      expect(result.success, isTrue);
      expect(result.message, contains('connected to'));
    });

    test('reports success on "already connected"', () async {
      final exec = FakeCommandExec(
        (_, _) => FakeCommandExec.ok('already connected to 192.168.1.10:5555'),
      );

      expect(
        (await service(exec).connectDevice('192.168.1.10:5555')).success,
        isTrue,
      );
    });

    test('reports failure with stderr message', () async {
      final exec = FakeCommandExec(
        (_, _) => FakeCommandExec.fail('cannot connect'),
      );

      final result = await service(exec).connectDevice('192.168.1.10:5555');

      expect(result.success, isFalse);
      expect(result.message, 'cannot connect');
    });
  });

  group('disconnectDevice / enableTcpIp', () {
    test('disconnectDevice mirrors command success', () async {
      final ok = FakeCommandExec((_, _) => FakeCommandExec.ok());
      final bad = FakeCommandExec((_, _) => FakeCommandExec.fail());

      expect(await service(ok).disconnectDevice('h'), isTrue);
      expect(await service(bad).disconnectDevice('h'), isFalse);
    });

    test('enableTcpIp passes serial and port', () async {
      final exec = FakeCommandExec((_, _) => FakeCommandExec.ok());

      final result = await service(exec).enableTcpIp('emulator-5554');

      expect(result, isTrue);
      expect(exec.calls.last.arguments, [
        '-s',
        'emulator-5554',
        'tcpip',
        '5555',
      ]);
    });
  });

  group('getDeviceIpAddress', () {
    test('extracts ip from "ip route" src', () async {
      final exec = FakeCommandExec((command, args) {
        if (args.contains('route')) {
          return FakeCommandExec.ok(
            '192.168.1.0/24 dev wlan0 proto kernel scope link src 192.168.1.42',
          );
        }
        return FakeCommandExec.fail();
      });

      expect(await service(exec).getDeviceIpAddress('s'), '192.168.1.42');
    });

    test('falls back to ifconfig when ip route has no src', () async {
      final exec = FakeCommandExec((command, args) {
        if (args.contains('route')) return FakeCommandExec.ok('no src here');
        if (args.contains('ifconfig')) {
          return FakeCommandExec.ok('inet addr:192.168.1.99  Bcast:...');
        }
        return FakeCommandExec.fail();
      });

      expect(await service(exec).getDeviceIpAddress('s'), '192.168.1.99');
    });

    test('returns null when nothing matches', () async {
      final exec = FakeCommandExec((_, _) => FakeCommandExec.ok('nothing'));

      expect(await service(exec).getDeviceIpAddress('s'), isNull);
    });
  });

  group('getWirelessPairingInfo', () {
    test('returns null for sdk < 30', () async {
      final exec = FakeCommandExec((command, args) {
        if (args.contains('getprop')) return FakeCommandExec.ok('29');
        return FakeCommandExec.fail();
      });

      expect(await service(exec).getWirelessPairingInfo('s'), isNull);
    });

    test('returns pairing info for sdk >= 30 with an ip', () async {
      final exec = FakeCommandExec((command, args) {
        if (args.contains('getprop')) return FakeCommandExec.ok('33');
        if (args.contains('route')) {
          return FakeCommandExec.ok('... src 192.168.1.50');
        }
        return FakeCommandExec.fail();
      });

      final info = await service(exec).getWirelessPairingInfo('s');

      expect(info, isNotNull);
      expect(info!.deviceIp, '192.168.1.50');
      expect(info.defaultPort, 5555);
      expect(info.supportsWirelessDebugging, isTrue);
    });
  });

  group('pairDevice', () {
    test('succeeds on "Successfully paired"', () async {
      final exec = FakeCommandExec(
        (_, _) => FakeCommandExec.fail('', 'Successfully paired to ...'),
      );

      final result = await service(exec).pairDevice('h:port', '123456');

      expect(result.success, isTrue);
      expect(result.message, contains('Successfully paired'));
    });

    test('fails with stderr on error', () async {
      final exec = FakeCommandExec(
        (_, _) => FakeCommandExec.fail('pairing failed'),
      );

      final result = await service(exec).pairDevice('h:port', '000000');

      expect(result.success, isFalse);
      expect(result.message, 'pairing failed');
    });
  });

  group('launchDevice', () {
    test('prefixes the avd id with @ and appends extra args', () async {
      final exec = FakeCommandExec((_, _) => FakeCommandExec.ok());

      await service(
        exec,
      ).launchDevice(deviceId: 'Pixel_7', additionalArgs: ['-no-audio']);

      expect(exec.calls.single.command, emulatorPath);
      expect(exec.calls.single.arguments, ['@Pixel_7', '-no-audio']);
    });
  });

  group('shutdownSimulator', () {
    test('issues emu kill and mirrors success', () async {
      final exec = FakeCommandExec((_, _) => FakeCommandExec.ok());

      final result = await service(
        exec,
      ).shutdownSimulator(deviceId: 'emulator-5554');

      expect(result, isTrue);
      expect(exec.calls.single.arguments, [
        '-s',
        'emulator-5554',
        'emu',
        'kill',
      ]);
    });
  });

  group('isAvailable', () {
    test('true when sdk present and both probes succeed', () async {
      final exec = FakeCommandExec((_, _) => FakeCommandExec.ok());

      expect(await service(exec).isAvailable(), isTrue);
    });

    test('false when a probe fails', () async {
      final exec = FakeCommandExec((command, args) {
        if (command == adbPath) return FakeCommandExec.ok();
        return FakeCommandExec.fail();
      });

      expect(await service(exec).isAvailable(), isFalse);
    });

    test('false when sdk binaries are missing', () async {
      final exec = FakeCommandExec((_, _) => FakeCommandExec.ok());
      final svc = AndroidDeviceService(
        exec,
        androidHomeOverride: '${sdkDir.path}/missing',
      );

      expect(await svc.isAvailable(), isFalse);
    });
  });
}
