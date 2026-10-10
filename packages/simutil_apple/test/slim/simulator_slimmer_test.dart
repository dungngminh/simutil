import 'dart:io';

import 'package:simutil_apple/simutil_apple.dart';
import 'package:simutil_core/testing.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  const udid = 'ABC';

  setUp(() => root = Directory.systemTemp.createTempSync('slim_'));
  tearDown(() => root.deleteSync(recursive: true));

  File store() => File(
    '${root.path}/com.apple.CoreSimulator.SimDevice.$udid/disabled.plist',
  );

  test(
    'slim on a shut down device writes the store, keeps excepted and foreign entries',
    () async {
      store()
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '<plist><dict><key>com.example.own</key><false/></dict></plist>',
        );
      final exec = FakeCommandExec(
        (cmd, args) => FakeCommandExec.ok('Shutdown'),
      );
      final slimmer = SimulatorSlimmer(exec, storeRoot: root.path);

      await slimmer.slim(udid, except: {'search'});

      final xml = store().readAsStringSync();
      expect(xml, contains('<key>com.apple.siriactionsd</key>\n\t<true/>'));
      expect(xml, contains('<key>com.apple.searchd</key>\n\t<false/>'));
      expect(xml, contains('<key>com.apple.sharingd</key>\n\t<false/>'));
      expect(xml, contains('<key>com.example.own</key>\n\t<false/>'));
      expect(await slimmer.isSlim(udid), isTrue);
      expect(exec.calls.map((c) => c.arguments[1]), ['list']);

      await slimmer.unslim(udid);
      expect(await slimmer.isSlim(udid), isFalse);
    },
  );

  test('slim reboots a booted device around the store write', () async {
    final exec = FakeCommandExec(
      (cmd, args) =>
          FakeCommandExec.ok(args[1] == 'list' ? 'iPhone (ABC) (Booted)' : ''),
    );
    await SimulatorSlimmer(exec, storeRoot: root.path).slim(udid);
    expect(exec.calls.map((c) => c.arguments[1]), ['list', 'shutdown', 'boot']);
  });
}
