import 'package:args/command_runner.dart';
import 'package:platform/platform.dart';
import 'package:simutil/src/cli/commands/platform_commands.dart';
import 'package:test/test.dart';

void main() {
  test('ios off macOS is a usage error, not a missing run()', () async {
    final runner = CommandRunner<int>(
      'simutil',
      'test',
    )..addCommand(IosCommand(platform: FakePlatform(operatingSystem: 'linux')));

    await expectLater(
      runner.run(['ios']),
      throwsA(
        isA<UsageException>().having(
          (e) => e.message,
          'message',
          'iOS simulators and devices need macOS.',
        ),
      ),
    );
  });
}
