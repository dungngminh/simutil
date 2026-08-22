import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:simutil_cli/src/cli_device_services.dart';
import 'package:simutil_cli/src/commands/simutil_command.dart';
import 'package:simutil_core/simutil_core.dart';

/// Lists emulators, simulators, and connected hardware.
class ListCommand extends SimutilCommand {
  /// Creates the `list` subcommand.
  ListCommand({super.logger, CliDeviceServices? services})
    : _services = services ?? CliDeviceServices();

  final CliDeviceServices _services;

  @override
  String get name => 'list';

  @override
  List<String> get aliases => const ['ls'];

  @override
  String get description => 'List devices';

  @override
  ArgParser get argParser => configuredArgParser((parser) {
    addPlatformFlags(parser);
    parser
      ..addFlag(
        'emulator',
        abbr: 'e',
        help: 'Include emulators and simulators.',
        defaultsTo: true,
      )
      ..addFlag(
        'physical',
        abbr: 'p',
        help: 'Include physical devices.',
        defaultsTo: true,
      )
      ..addFlag(
        'running',
        abbr: 'r',
        help: 'Show only running devices.',
        negatable: false,
      );
  });

  @override
  Future<int> run() async {
    final androidOnly = argResults!['android'] == true;
    final iosOnly = argResults!['ios'] == true;
    if (androidOnly && iosOnly) {
      throw UsageException('Use only one of -a/--android or -i/--ios.', usage);
    }

    final includeEmulator = argResults!['emulator'] as bool;
    final includePhysical = argResults!['physical'] as bool;
    if (!includeEmulator && !includePhysical) {
      throw UsageException('At least one of -e/--emulator or -p/--physical.', usage);
    }

    final devices = await _services.listDevices(
      android: !iosOnly,
      ios: !androidOnly,
      emulator: includeEmulator,
      physical: includePhysical,
      runningOnly: argResults!['running'] == true,
    );

    if (devices.isEmpty) {
      logger.warn('No devices found.');
      return 0;
    }

    for (final device in devices) {
      logger.info(_formatDevice(device));
    }
    return 0;
  }

  String _formatDevice(Device device) {
    return [
      device.id,
      device.name,
      device.os.name,
      device.type.name,
      device.state.label,
    ].join('\t');
  }
}
