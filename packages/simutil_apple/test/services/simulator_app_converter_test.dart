import 'dart:io';

import 'package:simutil_apple/simutil_apple.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_core/testing.dart';
import 'package:test/test.dart';

const _thin = [0xcf, 0xfa, 0xed, 0xfe, 0, 0, 0, 0];
const _fat = [0xca, 0xfe, 0xba, 0xbe, 0, 0, 0, 0];

/// `Runner.app` with a thin executable, a fat framework and a plist.
Directory _bundle() {
  final app = Directory(
    '${Directory.systemTemp.createTempSync('sim_conv').path}/Runner.app',
  )..createSync();
  File('${app.path}/Runner').writeAsBytesSync(_thin);
  File('${app.path}/Info.plist').writeAsStringSync('<plist/>');
  final framework = Directory('${app.path}/Frameworks/A.framework')
    ..createSync(recursive: true);
  File('${framework.path}/A').writeAsBytesSync(_fat);
  addTearDown(() => app.parent.deleteSync(recursive: true));
  return app;
}

/// Answers like the real tools, writing the `-output` files they create.
FakeCommandExec _tools({String otool = 'cryptid 0'}) =>
    FakeCommandExec((command, args) {
      if (command == 'otool') return FakeCommandExec.ok(otool);
      if (command == 'vtool' && args.first == '-show-build') {
        return FakeCommandExec.ok('platform IOS\n   minos 15.0\n     sdk 18.2');
      }
      final output = args.indexOf('-output');
      if (output >= 0) File(args[output + 1]).writeAsBytesSync(_thin);
      return FakeCommandExec.ok();
    });

void main() {
  test('thins, re-tags and signs every Mach-O, nested code first', () async {
    final app = _bundle();
    final exec = _tools();
    await convertForSimulator(exec, app.path);

    final framework = '${app.path}/Frameworks/A.framework';
    String args(String command, [String? first]) => exec.calls
        .where((c) => c.command == command)
        .where((c) => first == null || c.arguments.first == first)
        .map((c) => c.arguments.join(' '))
        .join('\n');
    expect(args('lipo'), '$framework/A -thin arm64 -output $framework/A.thin');
    expect(
      args('vtool', '-set-build-version'),
      allOf(
        contains(
          'iossim 15.0 18.2 -replace -output ${app.path}/Runner.sim '
          '${app.path}/Runner',
        ),
        contains('-output $framework/A.sim $framework/A'),
      ),
    );
    expect(args('codesign'), '-f -s - $framework\n-f -s - ${app.path}');
    expect(File('$framework/A.sim').existsSync(), isFalse);
  });

  test('refuses an encrypted app before changing anything', () async {
    final app = _bundle();
    final exec = _tools(otool: 'cryptid 1');
    await expectLater(
      convertForSimulator(exec, app.path),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('encrypted'),
        ),
      ),
    );
    expect(exec.calls.map((c) => c.command).toSet(), {'otool'});
  });

  test('installForSimulator converts a copy and installs it', () async {
    final app = _bundle();
    final exec = _tools();
    String? copy;
    final ditto = FakeCommandExec((command, args) {
      if (command == 'ditto') {
        copy = args[1];
        _copy(Directory(args[0]), args[1]);
        return FakeCommandExec.ok();
      }
      return exec.handler(command, args);
    });
    final sim = Device.ios(
      id: 'UDID',
      name: 'iPhone',
      state: DeviceState.booted,
      type: DeviceType.simulator,
    );
    await IosAutomation(ditto).installForSimulator(sim, app.path);

    expect(ditto.calls.last.arguments, ['simctl', 'install', 'UDID', copy]);
    expect(copy, isNot(app.path));
    expect(File('${app.path}/Runner').readAsBytesSync(), _thin);
    expect(Directory(copy!).existsSync(), isFalse);
  });
}

void _copy(Directory from, String to) {
  for (final entry in from.listSync(recursive: true)) {
    if (entry is! File) continue;
    final target = File('$to${entry.path.substring(from.path.length)}');
    target.parent.createSync(recursive: true);
    entry.copySync(target.path);
  }
}
