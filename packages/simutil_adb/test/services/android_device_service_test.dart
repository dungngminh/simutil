import 'dart:io';

import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_adb/src/android_device_service.dart';
import 'package:test/test.dart';

import 'package:simutil_core/testing.dart';

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

  AndroidDeviceService service(FakeCommandExec exec) => AndroidDeviceService(
    exec,
    androidHomeOverride: sdkDir.path,
    isWindows: false,
  );

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
        isWindows: false,
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
        isWindows: false,
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
        isWindows: false,
      );

      expect(svc.getAndroidHome(), '/home/test/Android/Sdk');
      expect(svc.adbPath, '/home/test/Android/Sdk/platform-tools/adb');
    }, skip: !Platform.isLinux);

    test('falls back to adb on PATH when SDK adb is missing', () {
      final svc = AndroidDeviceService(
        FakeCommandExec((_, _) => null),
        environment: {'HOME': '/home/test'},
        fileExists: (_) => false,
        isWindows: false,
      );

      expect(svc.adbPath, 'adb');
    });

    test('finds Homebrew adb when the SDK has none', () {
      final svc = AndroidDeviceService(
        FakeCommandExec((_, _) => null),
        environment: {'HOME': '/Users/test'},
        fileExists: (path) => path == '/opt/homebrew/bin/adb',
        isWindows: false,
      );

      expect(svc.adbPath, '/opt/homebrew/bin/adb');
    });

    test('finds winget adb when the SDK has none', () {
      const local = r'C:\Users\test\AppData\Local';
      final svc = AndroidDeviceService(
        FakeCommandExec((_, _) => null),
        environment: {'LOCALAPPDATA': local},
        fileExists: (path) => path == '$local/Microsoft/WinGet/Links/adb.exe',
        isWindows: true,
      );

      expect(svc.adbPath, '$local/Microsoft/WinGet/Links/adb.exe');
    });

    test('uses .exe binaries and LOCALAPPDATA SDK on Windows', () {
      const sdk = r'C:\Users\test\AppData\Local/Android/Sdk';
      final svc = AndroidDeviceService(
        FakeCommandExec((_, _) => null),
        environment: {'LOCALAPPDATA': r'C:\Users\test\AppData\Local'},
        fileExists: (path) => path == '$sdk/platform-tools/adb.exe',
        isWindows: true,
      );

      expect(svc.getAndroidHome(), sdk);
      expect(svc.adbPath, '$sdk/platform-tools/adb.exe');
      expect(svc.emulatorPath, '$sdk/emulator/emulator.exe');
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

    test('headless adds the no-window flags', () async {
      final exec = FakeCommandExec((_, _) => FakeCommandExec.ok());

      await service(exec).launchDevice(deviceId: 'Pixel_7', headless: true);

      expect(exec.calls.single.arguments, [
        '@Pixel_7',
        ...AndroidDeviceService.headlessArgs,
        ...AndroidDeviceService.headlessGpuArgs,
      ]);
    });

    test('headless keeps the gpu mode the caller passes', () async {
      final exec = FakeCommandExec((_, _) => FakeCommandExec.ok());

      await service(exec).launchDevice(
        deviceId: 'Pixel_7',
        headless: true,
        additionalArgs: ['-gpu', 'swiftshader_indirect'],
      );

      expect(exec.calls.single.arguments, [
        '@Pixel_7',
        ...AndroidDeviceService.headlessArgs,
        '-gpu',
        'swiftshader_indirect',
      ]);
    });

    test('headless does not repeat flags the caller passes', () async {
      final exec = FakeCommandExec((_, _) => FakeCommandExec.ok());

      await service(exec).launchDevice(
        deviceId: 'Pixel_7',
        headless: true,
        additionalArgs: ['-no-audio', '-no-snapshot-load'],
      );

      expect(exec.calls.single.arguments, [
        '@Pixel_7',
        ...AndroidDeviceService.headlessArgs,
        ...AndroidDeviceService.headlessGpuArgs,
        '-no-snapshot-load',
      ]);
    });
  });

  group('deleteSimulator', () {
    late Directory avdHome;
    setUp(() => avdHome = Directory('${sdkDir.path}/avd')..createSync());

    AndroidDeviceService avdService() => AndroidDeviceService(
      FakeCommandExec((_, _) => null),
      androidHomeOverride: sdkDir.path,
      environment: {'ANDROID_AVD_HOME': avdHome.path},
      isWindows: false,
    );

    test('removes the ini and the directory it points to', () async {
      final elsewhere = Directory('${sdkDir.path}/elsewhere/Pixel_7.avd')
        ..createSync(recursive: true);
      File('${elsewhere.path}/config.ini').writeAsStringSync('x');
      final ini = File('${avdHome.path}/Pixel_7.ini')
        ..writeAsStringSync('avd.ini.encoding=UTF-8\npath=${elsewhere.path}\n');

      expect(await avdService().deleteSimulator(deviceId: 'Pixel_7'), isTrue);
      expect(ini.existsSync(), isFalse);
      expect(elsewhere.existsSync(), isFalse);
    });

    test('false for an unknown AVD', () async {
      expect(await avdService().deleteSimulator(deviceId: 'Nope'), isFalse);
    });
  });

  group('wipeData', () {
    test('removes user data and snapshots, keeps the config', () async {
      final avdHome = Directory('${sdkDir.path}/avd')..createSync();
      final avd = Directory('${avdHome.path}/Pixel_7.avd')..createSync();
      for (final f in ['config.ini', 'userdata-qemu.img', 'cache.img']) {
        File('${avd.path}/$f').writeAsStringSync('x');
      }
      Directory(
        '${avd.path}/snapshots/default_boot',
      ).createSync(recursive: true);
      File(
        '${avdHome.path}/Pixel_7.ini',
      ).writeAsStringSync('path=${avd.path}\n');
      final service = AndroidDeviceService(
        FakeCommandExec((_, _) => null),
        androidHomeOverride: sdkDir.path,
        environment: {'ANDROID_AVD_HOME': avdHome.path},
        isWindows: false,
      );

      expect(await service.wipeData(deviceId: 'Pixel_7'), isTrue);
      expect(avd.listSync().map((e) => e.uri.pathSegments.last), [
        'config.ini',
      ]);
      expect(await service.wipeData(deviceId: 'Nope'), isFalse);
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
        isWindows: false,
      );

      expect(await svc.isAvailable(), isFalse);
    });
  });

  group('Android versions', () {
    test('androidPlatformName maps API levels to versions', () {
      expect(androidPlatformName('android-35'), 'Android 15');
      expect(androidPlatformName('android-32'), 'Android 12L');
      expect(androidPlatformName('36'), 'Android 16');
      expect(androidPlatformName('android-99'), 'Android API 99');
      expect(androidPlatformName(null), 'Android');
      expect(androidPlatformName('android-Baklava'), 'Android');
    });

    test('emulators read their version from the AVD ini', () async {
      final avdHome = Directory('${sdkDir.path}/avd')..createSync();
      File(
        '${avdHome.path}/Pixel_7.ini',
      ).writeAsStringSync('avd.ini.encoding=UTF-8\ntarget=android-34\n');
      final exec = FakeCommandExec((command, args) {
        if (command == emulatorPath && args.contains('-list-avds')) {
          return FakeCommandExec.ok('Pixel_7\nNo_Ini\n');
        }
        return null;
      });
      final devices = await AndroidDeviceService(
        exec,
        androidHomeOverride: sdkDir.path,
        environment: {'ANDROID_AVD_HOME': avdHome.path},
        isWindows: false,
      ).getSimulators();
      expect(devices.map((d) => d.platform), ['Android 14', 'Android']);
    });

    test('booted hardware reports ro.build.version.release', () async {
      final exec = FakeCommandExec((command, args) {
        if (args.join(' ') == 'devices -l') {
          return FakeCommandExec.ok(
            'List of devices attached\n'
            'ABC123 device product:foo model:Pixel_8 device:husky\n'
            'DEF456 unauthorized\n',
          );
        }
        if (args.contains('ro.build.version.release')) {
          return FakeCommandExec.ok('15\n');
        }
        return null;
      });
      final devices = await service(exec).getPhysicalDevices();
      expect(devices.map((d) => d.platform), ['Android 15', 'Android']);
      // Only the booted device is asked.
      expect(
        exec.calls.where((c) => c.arguments.contains('getprop')),
        hasLength(1),
      );
    });
  });

  test('listWebcams parses emulator -webcam-list', () async {
    final exec = FakeCommandExec(
      (_, args) => args.contains('-webcam-list')
          ? FakeCommandExec.ok('''
List of web cameras connected to the computer:
 Camera 'webcam0' is connected to device 'FaceTime HD Camera' on channel 0 using pixel format 'YV12'
 Camera 'webcam1' is connected to device 'iPhone Camera' on channel 0 using pixel format 'YV12'
''')
          : null,
    );

    expect(await service(exec).listWebcams(), [
      (id: 'webcam0', name: 'FaceTime HD Camera'),
      (id: 'webcam1', name: 'iPhone Camera'),
    ]);
    expect(
      await service(FakeCommandExec((_, _) => null)).listWebcams(),
      isEmpty,
    );
  });
}
