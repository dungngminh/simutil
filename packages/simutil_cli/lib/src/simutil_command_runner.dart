import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:simutil_cli/src/cli_catalog.dart';
import 'package:simutil_cli/src/commands/schema_command.dart';
import 'package:simutil_cli/src/commands/launch_command.dart';
import 'package:simutil_cli/src/commands/list_command.dart';
import 'package:simutil_cli/src/commands/platform_commands.dart';
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
        'Launch and manage Android emulators / Apple simulators from the terminal',
      ) {
    argParser.addFlag(
      'version',
      abbr: 'V',
      help: 'Print the current version (-V, --version).',
      negatable: false,
    );
    addCommand(AndroidCommand(logger: _logger));
    addCommand(IosCommand(logger: _logger));
    addCommand(ListCommand(logger: _logger));
    addCommand(LaunchCommand(logger: _logger));
    addCommand(ShutdownCommand(logger: _logger));
    addCommand(PluginCommand(logger: _logger));
    addCommand(SchemaCommand(logger: _logger, version: _version));
    addCommand(VersionCommand(logger: _logger, version: _version));
  }

  final Logger _logger;
  final String _version;

  @override
  String get usage => formatCliOverviewHelp(
    version: _version,
    catalog: simutilCliCatalog(version: _version),
  );

  @override
  Future<int> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults['version'] == true) {
      _logger.success('Simutil v$_version');
      return 0;
    }
    return await super.runCommand(topLevelResults) ?? 1;
  }
}
