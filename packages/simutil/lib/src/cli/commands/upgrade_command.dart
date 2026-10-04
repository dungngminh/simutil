import 'dart:io';

import 'package:simutil/src/cli/commands/simutil_command.dart';
import 'package:simutil/src/cli/commands/version_command.dart';
import 'package:simutil_shared/simutil_shared.dart';

/// Runs [command] in a shell; returns its exit code.
typedef RunShell = Future<int> Function(String command);

/// Upgrades simutil through the channel it was installed with.
class UpgradeCommand extends SimutilCommand {
  /// Creates the `upgrade` subcommand.
  UpgradeCommand({
    super.logger,
    required this.version,
    this.updateChecker,
    RunShell? runShell,
    bool? isWindows,
  }) : _runShell = runShell ?? _defaultRunShell,
       _isWindows = isWindows ?? Platform.isWindows;

  /// Installed version.
  final String version;

  /// Release check.
  final UpdateChecker? updateChecker;

  final RunShell _runShell;
  final bool _isWindows;

  @override
  String get name => 'upgrade';

  @override
  String get description => 'Upgrade simutil to the latest release';

  @override
  Future<int> run() async {
    final update = await updateChecker?.check(version, force: true);
    if (update == null) {
      logger.success('Simutil v$version is up to date.');
      return 0;
    }
    final command = update.source.upgradeCommand;
    if (command == null) {
      printUpdateHint(logger, update);
      return 0;
    }
    if (_isWindows) {
      printUpdateHint(logger, update, action: 'Close simutil and run');
      return 0;
    }
    logger.info('Upgrading simutil v$version → v${update.latestVersion}…');
    final code = await _runShell(command);
    if (code != 0) {
      logger.err('Upgrade failed (exit $code). Run manually: $command');
    }
    return code;
  }
}

Future<int> _defaultRunShell(String command) async {
  final process = await Process.start('sh', [
    '-c',
    command,
  ], mode: ProcessStartMode.inheritStdio);
  return process.exitCode;
}
