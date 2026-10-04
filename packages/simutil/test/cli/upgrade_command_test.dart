import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:simutil/src/cli/commands/upgrade_command.dart';
import 'package:simutil_shared/simutil_shared.dart';
import 'package:test/test.dart';

class _FakeChecker implements UpdateChecker {
  _FakeChecker(this.info);
  final UpdateInfo? info;
  bool? forced;

  @override
  Future<UpdateInfo?> check(String currentVersion, {bool force = false}) async {
    forced = force;
    return info;
  }
}

void main() {
  late List<String> ran;

  Future<int?> upgrade(
    UpdateInfo? info, {
    bool isWindows = false,
    int exitCode = 0,
    _FakeChecker? checker,
  }) =>
      (CommandRunner<int>('simutil', '')..addCommand(
            UpgradeCommand(
              logger: Logger(level: Level.quiet),
              version: '1.0.0',
              updateChecker: checker ?? _FakeChecker(info),
              isWindows: isWindows,
              runShell: (command) async {
                ran.add(command);
                return exitCode;
              },
            ),
          ))
          .run(['upgrade']);

  setUp(() => ran = []);

  const brew = UpdateInfo(
    latestVersion: '1.2.0',
    source: InstallSource.homebrew,
  );

  test('runs the channel upgrade command with a forced check', () async {
    final checker = _FakeChecker(brew);
    expect(await upgrade(brew, checker: checker), 0);
    expect(checker.forced, isTrue);
    expect(ran, ['brew upgrade dungngminh/simutil/simutil']);
  });

  test('propagates a failed upgrade exit code', () async {
    expect(await upgrade(brew, exitCode: 3), 3);
  });

  test('does nothing when up to date', () async {
    expect(await upgrade(null), 0);
    expect(ran, isEmpty);
  });

  test('only prints for source checkouts and Windows', () async {
    await upgrade(
      const UpdateInfo(latestVersion: '1.2.0', source: InstallSource.source),
    );
    await upgrade(
      const UpdateInfo(
        latestVersion: '1.2.0',
        source: InstallSource.powershell,
      ),
      isWindows: true,
    );
    expect(ran, isEmpty);
  });
}
