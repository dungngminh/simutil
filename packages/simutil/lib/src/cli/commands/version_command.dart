import 'package:mason_logger/mason_logger.dart';
import 'package:simutil/src/cli/commands/simutil_command.dart';
import 'package:simutil_shared/simutil_shared.dart';

/// Prints `Simutil v[version]`, then an upgrade hint when [updateChecker]
/// finds a newer release.
///
/// The first line is asserted by the Homebrew formula test; keep it stable.
Future<void> printVersion(
  Logger logger,
  String version,
  UpdateChecker? updateChecker,
) async {
  logger.success('Simutil v$version');
  final update = await updateChecker?.check(version);
  if (update == null) return;
  printUpdateHint(logger, update);
}

/// Prints `Version X available! Run: <cmd>`.
void printUpdateHint(Logger logger, UpdateInfo update, {String? action}) {
  final label =
      action ?? (update.source.upgradeCommand != null ? 'Run' : 'See');
  logger.info(
    yellow.wrap('Version ${update.latestVersion} available! $label: ')! +
        styleBold.wrap(yellow.wrap(update.instruction))!,
  );
}

/// Prints the installed SimUtil package version.
class VersionCommand extends SimutilCommand {
  /// Creates the `version` subcommand.
  VersionCommand({super.logger, required this.version, this.updateChecker});

  /// App or package version string shown to the user.
  final String version;

  /// Optional new-release check; `null` skips it.
  final UpdateChecker? updateChecker;

  /// Subcommand name (`version`).
  @override
  String get name => 'version';

  /// Short help text for the subcommand.
  @override
  String get description => 'Print the current version';

  /// Prints the package version and returns exit code `0`.
  @override
  Future<int> run() async {
    await printVersion(logger, version, updateChecker);
    return 0;
  }
}
