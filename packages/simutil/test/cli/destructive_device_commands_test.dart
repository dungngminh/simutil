import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:simutil/src/cli/cli_device_services.dart';
import 'package:simutil/src/cli/commands/destructive_device_commands.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_core/testing.dart';
import 'package:test/test.dart';

/// Answers every confirm with [answer] and counts prompts.
class _Logger extends Logger {
  _Logger({this.answer = false}) : super(level: Level.quiet);

  final bool answer;
  int prompts = 0;

  @override
  bool confirm(String? message, {bool defaultValue = false}) {
    prompts++;
    return answer;
  }
}

void main() {
  final stopped = testAndroidEmulator(state: DeviceState.shutdown);
  final running = testAndroidEmulator(id: 'Running_AVD');

  late FakeDeviceService android;

  setUp(() {
    android = FakeDeviceService(simulators: [stopped, running]);
  });

  Future<int?> run(_Logger logger, List<String> args) {
    final services = CliDeviceServices(services: {DeviceOs.android: android});
    final runner = CommandRunner<int>('simutil', '')
      ..addCommand(WipeCommand(logger: logger, services: services))
      ..addCommand(DeleteCommand(logger: logger, services: services));
    return runner.run(args);
  }

  test('wipe asks and does nothing when declined', () async {
    final logger = _Logger();
    expect(await run(logger, ['wipe', stopped.id]), 1);
    expect(logger.prompts, 1);
    expect(android.wiped, <String>[]);
  });

  test('wipe runs after yes', () async {
    expect(await run(_Logger(answer: true), ['wipe', stopped.id]), 0);
    expect(android.wiped, [stopped.id]);
  });

  test('delete --yes skips the prompt', () async {
    final logger = _Logger();
    expect(await run(logger, ['delete', stopped.id, '--yes']), 0);
    expect(logger.prompts, 0);
    expect(android.deleted, [stopped.id]);
  });

  test('refuses a running device without prompting', () async {
    final logger = _Logger(answer: true);
    expect(await run(logger, ['delete', running.id, '-y']), 1);
    expect(logger.prompts, 0);
    expect(android.deleted, <String>[]);
  });
}
