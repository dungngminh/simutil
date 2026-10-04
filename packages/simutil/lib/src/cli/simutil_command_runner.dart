import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:simutil/src/cli/cli_catalog.dart';
import 'package:simutil/src/cli/commands/schema_command.dart';
import 'package:simutil/src/cli/commands/launch_command.dart';
import 'package:simutil/src/cli/commands/list_command.dart';
import 'package:simutil/src/cli/commands/platform_commands.dart';
import 'package:simutil/src/cli/commands/plugin_command.dart';
import 'package:simutil/src/cli/commands/shutdown_command.dart';
import 'package:simutil/src/cli/commands/upgrade_command.dart';
import 'package:simutil/src/cli/commands/version_command.dart';
import 'package:simutil_shared/simutil_shared.dart';

/// CLI entry point registering SimUtil subcommands.
class SimutilCommandRunner extends CommandRunner<int> {
  /// Creates the root `simutil` command runner. [updateChecker] adds a
  /// new-release hint to `version` / `--version` and powers `upgrade`.
  SimutilCommandRunner({
    Logger? logger,
    required String version,
    UpdateChecker? updateChecker,
  }) : _logger = logger ?? Logger(),
       _version = version,
       _updateChecker = updateChecker,
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
    addCommand(
      UpgradeCommand(
        logger: _logger,
        version: _version,
        updateChecker: _updateChecker,
      ),
    );
    addCommand(
      VersionCommand(
        logger: _logger,
        version: _version,
        updateChecker: _updateChecker,
      ),
    );
  }

  final Logger _logger;
  final String _version;
  final UpdateChecker? _updateChecker;

  @override
  String get usage => formatCliOverviewHelp(
    version: _version,
    catalog: simutilCliCatalog(version: _version),
  );

  @override
  Future<int> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults['version'] == true) {
      await printVersion(_logger, _version, _updateChecker);
      return 0;
    }
    return await super.runCommand(topLevelResults) ?? 1;
  }
}
