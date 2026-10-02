import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:simutil/src/cli/cli_device_services.dart';
import 'package:simutil/src/cli/cli_flags.dart';
import 'package:simutil/src/cli/cli_output.dart';
import 'package:simutil/src/cli/commands/simutil_command.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_plugins/simutil_plugins.dart';

/// Parent command for YAML plugin operations.
class PluginCommand extends SimutilCommand {
  /// Creates the `plugin` command group.
  PluginCommand({
    super.logger,
    CliDeviceServices? deviceServices,
    PluginCatalogLoader? loadCatalog,
    PluginRunner? runner,
  }) : _deviceServices = deviceServices ?? CliDeviceServices(),
       _loadCatalog = loadCatalog ?? loadPluginCatalog,
       _runner = runner ?? PluginRunner(CommandExecImpl()) {
    addSubcommand(
      PluginListCommand(
        logger: logger,
        loadCatalog: _loadCatalog,
        deviceServices: _deviceServices,
      ),
    );
    addSubcommand(
      PluginRunCommand(
        logger: logger,
        loadCatalog: _loadCatalog,
        runner: _runner,
        deviceServices: _deviceServices,
      ),
    );
  }

  final CliDeviceServices _deviceServices;
  final PluginCatalogLoader _loadCatalog;
  final PluginRunner _runner;

  @override
  String get name => 'plugin';

  @override
  String get description => 'List or run YAML plugins';
}

/// Lists configured plugins and their commands.
class PluginListCommand extends SimutilCommand {
  /// Creates the `plugin list` subcommand.
  PluginListCommand({
    super.logger,
    required PluginCatalogLoader loadCatalog,
    required CliDeviceServices deviceServices,
  }) : _loadCatalog = loadCatalog,
       _deviceServices = deviceServices;

  final PluginCatalogLoader _loadCatalog;
  final CliDeviceServices _deviceServices;

  @override
  String get name => 'list';

  @override
  String get description => 'List configured plugins';

  @override
  ArgParser get argParser => configuredArgParser((parser) {
    addPlatformFlags(parser);
    parser.addOption(
      'device',
      abbr: 'd',
      help: 'Filter commands by device id (-d, --device <id>).',
    );
    addJsonOutputFlag(parser);
  });

  @override
  Future<int> run() async {
    final catalog = await _loadCatalog();
    catalog.warnings.forEach(logger.warn);

    Device? device;
    final deviceId = argResults!['device'] as String?;
    if (deviceId != null && deviceId.isNotEmpty) {
      device = await _deviceServices.resolveDevice(
        deviceId,
        osHint: osHintFromFlags(argResults!),
      );
    }

    final plugins = device == null
        ? catalog.plugins
        : catalog.forDevice(device);

    if (plugins.isEmpty) {
      logger.warn('No plugins found.');
      return 0;
    }

    if (jsonOutputRequested(argResults!)) {
      writeJsonStdout({
        'count': plugins.length,
        'plugins': plugins
            .map(
              (plugin) => {
                'id': plugin.id,
                'label': plugin.label,
                'commands':
                    (device == null
                            ? plugin.commands
                            : plugin.commandsFor(device))
                        .map(
                          (command) => {
                            'id': command.id,
                            'label': command.label,
                            'command': command.command,
                          },
                        )
                        .toList(),
              },
            )
            .toList(),
      });
      return 0;
    }

    for (final plugin in plugins) {
      logger.info('${plugin.id}  ${plugin.label}');
      final commands = device == null
          ? plugin.commands
          : plugin.commandsFor(device);
      for (final command in commands) {
        logger.info('  ${command.id}  ${command.label}');
      }
    }
    return 0;
  }
}

/// Runs a plugin command for an optional device.
class PluginRunCommand extends SimutilCommand {
  /// Creates the `plugin run` subcommand.
  PluginRunCommand({
    super.logger,
    required PluginCatalogLoader loadCatalog,
    required PluginRunner runner,
    required CliDeviceServices deviceServices,
  }) : _loadCatalog = loadCatalog,
       _runner = runner,
       _deviceServices = deviceServices;

  final PluginCatalogLoader _loadCatalog;
  final PluginRunner _runner;
  final CliDeviceServices _deviceServices;

  @override
  String get name => 'run';

  @override
  String get description => 'Run a plugin command';

  @override
  ArgParser get argParser => configuredArgParser((parser) {
    addPlatformFlags(parser);
    parser.addOption(
      'device',
      abbr: 'd',
      help: 'Target device id for templated args.',
    );
  });

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length < 2) {
      throw UsageException(
        'Usage: simutil plugin run <pluginId> <commandId>',
        usage,
      );
    }
    if (rest.length > 2) {
      throw UsageException('Unexpected extra arguments.', usage);
    }

    final catalog = await _loadCatalog();
    catalog.warnings.forEach(logger.warn);

    final pluginId = rest[0];
    final commandId = rest[1];
    if (catalog.plugin(pluginId) == null) {
      throw UsageException('Unknown plugin: $pluginId', usage);
    }
    final ref = catalog.command(pluginId, commandId);
    if (ref == null) {
      throw UsageException(
        'Unknown command "$commandId" for plugin "$pluginId"',
        usage,
      );
    }
    final PluginCommandRef(:plugin, :command) = ref;

    Device? device;
    final deviceId = argResults!['device'] as String?;
    if (deviceId != null && deviceId.isNotEmpty) {
      device = await _deviceServices.resolveDevice(
        deviceId,
        osHint: osHintFromFlags(argResults!),
      );
    }

    if (!command.matches(device)) {
      throw UsageException(
        'Command "$commandId" is not available for the selected device.',
        usage,
      );
    }

    final available = await _runner.isAvailable(plugin, command);
    if (!available) {
      logger.err('${command.command} is not installed or not on PATH.');
      return 1;
    }

    final result = await _runner.run(command, device);
    if (result.success) {
      logger.success(result.message);
      return 0;
    }

    logger.err(result.message);
    return 1;
  }
}
