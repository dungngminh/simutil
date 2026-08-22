import 'package:simutil/cli/commands/simutil_command.dart';
import 'package:simutil/utils/version.dart';

/// Prints the installed SimUtil package version.
class VersionCommand extends SimutilCommand {
  /// Creates the `version` subcommand.
  VersionCommand({super.logger});

  /// Subcommand name (`version`).
  @override
  String get name => 'version';

  /// Short help text for the subcommand.
  @override
  String get description => 'Print the current version';

  /// Prints the package version and returns exit code `0`.
  @override
  Future<int> run() async {
    logger.success('Simutil v$packageVersion');
    return 0;
  }
}
