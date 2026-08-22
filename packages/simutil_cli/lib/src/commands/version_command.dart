import 'package:simutil_cli/src/commands/simutil_command.dart';

/// Prints the installed SimUtil package version.
class VersionCommand extends SimutilCommand {
  /// Creates the `version` subcommand.
  VersionCommand({super.logger, required this.version});

  /// App or package version string shown to the user.
  final String version;

  /// Subcommand name (`version`).
  @override
  String get name => 'version';

  /// Short help text for the subcommand.
  @override
  String get description => 'Print the current version';

  /// Prints the package version and returns exit code `0`.
  @override
  Future<int> run() async {
    logger.success('Simutil v$version');
    return 0;
  }
}
