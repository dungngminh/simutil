import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:simutil_cli/src/commands/launch_command.dart';
import 'package:simutil_cli/src/commands/list_command.dart';
import 'package:simutil_cli/src/commands/plugin_command.dart';
import 'package:simutil_cli/src/commands/shutdown_command.dart';
import 'package:simutil_cli/src/commands/version_command.dart';

/// CLI entry point registering SimUtil subcommands.
class SimutilCommandRunner extends CommandRunner<int> {
  /// Creates the root `simutil` command runner.
  SimutilCommandRunner({Logger? logger, required String version})
    : _logger = logger ?? Logger(),
      _version = version,
      super(
        'simutil',
        'An utility TUI application for launching iOS simulators / Android emulators and more',
      ) {
    argParser.addFlag(
      'version',
      abbr: 'V',
      help: 'Print the current version.',
      negatable: false,
    );
    addCommand(ListCommand(logger: _logger));
    addCommand(LaunchCommand(logger: _logger));
    addCommand(ShutdownCommand(logger: _logger));
    addCommand(PluginCommand(logger: _logger));
    addCommand(VersionCommand(logger: _logger, version: _version));
  }

  final Logger _logger;
  final String _version;

  @override
  Future<int> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults['version'] == true) {
      _logger.success('Simutil v$_version');
      return 0;
    }
    return await super.runCommand(topLevelResults) ?? 1;
  }
}
