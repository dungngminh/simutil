import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:simutil/src/cli/commands/plugin_command.dart';
import 'package:simutil_plugins/simutil_plugins.dart';
import 'package:simutil_plugins/testing.dart';
import 'package:test/test.dart';

void main() {
  final catalog = PluginCatalog.parse('''
plugins:
  - id: tools
    label: Tools
    commands:
      - id: hello
        label: Hello
        command: echo
''');

  late FakePluginRunner runner;
  late CommandRunner<int> cli;

  setUp(() {
    runner = FakePluginRunner();
    cli = CommandRunner<int>('simutil', '')
      ..addCommand(
        PluginCommand(
          logger: Logger(level: Level.quiet),
          loadCatalog: () async => catalog,
          runner: runner,
        ),
      );
  });

  test('plugin run launches the command from the catalog', () async {
    expect(await cli.run(['plugin', 'run', 'tools', 'hello']), 0);
    expect(runner.ran.single.command.id, 'hello');
  });

  test(
    'plugin run returns the exit code of a failed inherit command',
    () async {
      runner.result = const PluginRunResult(
        success: false,
        message: 'Hello exited with code 3',
        exitCode: 3,
      );

      expect(await cli.run(['plugin', 'run', 'tools', 'hello']), 3);
    },
  );

  test('plugin run rejects unknown plugin and command ids', () {
    expect(
      cli.run(['plugin', 'run', 'nope', 'hello']),
      throwsA(isA<UsageException>()),
    );
    expect(
      cli.run(['plugin', 'run', 'tools', 'nope']),
      throwsA(isA<UsageException>()),
    );
  });
}
