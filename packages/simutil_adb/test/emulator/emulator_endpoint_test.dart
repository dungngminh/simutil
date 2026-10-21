import 'dart:io';

import 'package:simutil_adb/simutil_adb.dart';
import 'package:test/test.dart';

const _ini = '''
avd.id=Pixel_7_Pro
port.serial=5554
port.adb=5555
grpc.port=8554
grpc.token=secret
''';

void main() {
  group('EmulatorEndpoint.parse', () {
    test('reads port and token for the matching serial', () {
      final endpoint = EmulatorEndpoint.parse(_ini, serialPort: 5554)!;
      expect(endpoint.port, 8554);
      expect(endpoint.token, 'secret');
    });

    test('ignores another emulator', () {
      expect(EmulatorEndpoint.parse(_ini, serialPort: 5556), isNull);
    });

    test('null without grpc.port (-no-grpc)', () {
      expect(
        EmulatorEndpoint.parse('port.serial=5554\n', serialPort: 5554),
        isNull,
      );
    });

    test('no token when the emulator writes none', () {
      final endpoint = EmulatorEndpoint.parse(
        'port.serial=5554\r\ngrpc.port=8554\r\n',
        serialPort: 5554,
      )!;
      expect(endpoint.port, 8554);
      expect(endpoint.token, isNull);
    });
  });

  group('EmulatorEndpoint.find', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('avd-running-'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('matches the serial and prefers the newest file', () async {
      File('${dir.path}/pid_1.ini')
        ..writeAsStringSync(_ini.replaceFirst('8554', '9000'))
        ..setLastModifiedSync(DateTime(2020));
      File('${dir.path}/pid_2.ini').writeAsStringSync(_ini);
      File('${dir.path}/pid_3.ini').writeAsStringSync(
        _ini.replaceFirst('5554', '5556').replaceFirst('8554', '8556'),
      );
      File('${dir.path}/other.txt').writeAsStringSync(_ini);

      expect(
        (await EmulatorEndpoint.find(
          'emulator-5554',
          directory: dir.path,
        ))?.port,
        8554,
      );
      expect(
        (await EmulatorEndpoint.find(
          'emulator-5556',
          directory: dir.path,
        ))?.port,
        8556,
      );
    });

    test('null for devices, unknown emulators and missing dirs', () async {
      File('${dir.path}/pid_2.ini').writeAsStringSync(_ini);
      expect(
        await EmulatorEndpoint.find('R5CT1234', directory: dir.path),
        isNull,
      );
      expect(
        await EmulatorEndpoint.find('emulator-5558', directory: dir.path),
        isNull,
      );
      expect(
        await EmulatorEndpoint.find(
          'emulator-5554',
          directory: '${dir.path}/missing',
        ),
        isNull,
      );
    });
  });

  test('discoveryDirectory per platform', () {
    expect(
      EmulatorEndpoint.discoveryDirectory({
        'HOME': '/Users/me',
      }, operatingSystem: 'macos'),
      '/Users/me/Library/Caches/TemporaryItems/avd/running',
    );
    expect(
      EmulatorEndpoint.discoveryDirectory({
        'LOCALAPPDATA': r'C:\Users\me\AppData\Local',
      }, operatingSystem: 'windows'),
      r'C:\Users\me\AppData\Local\Temp\avd\running',
    );
    expect(
      EmulatorEndpoint.discoveryDirectory({
        'XDG_RUNTIME_DIR': '/run/user/1000',
      }, operatingSystem: 'linux'),
      '/run/user/1000/avd/running',
    );
    expect(
      EmulatorEndpoint.discoveryDirectory({
        'USER': 'me',
      }, operatingSystem: 'linux'),
      '/tmp/android-me/avd/running',
    );
  });
}
