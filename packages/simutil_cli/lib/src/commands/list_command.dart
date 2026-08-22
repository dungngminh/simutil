import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:simutil_cli/src/cli_device_services.dart';
import 'package:simutil_cli/src/cli_flags.dart';
import 'package:simutil_cli/src/cli_output.dart';
import 'package:simutil_cli/src/commands/device_list_command.dart';
import 'package:simutil_cli/src/commands/simutil_command.dart';

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
  String get description =>
      'List all devices (see also: android emulator list, ios simulator list)';

  @override
  String get usage => catalogUsage('list', 'simutil list|ls [options]');

  @override
  ArgParser get argParser => configuredArgParser((parser) {
    addPlatformFlags(parser);
    parser
      ..addFlag(
        'emulator',
        abbr: 'e',
        help: 'Include emulators and simulators (-e, --emulator)',
        defaultsTo: true,
      )
      ..addFlag(
        'physical',
        abbr: 'p',
        help: 'Include physical devices (-p, --physical)',
        defaultsTo: true,
      )
      ..addFlag(
        'running',
        abbr: 'r',
        help: 'Show only running devices (-r, --running)',
        negatable: false,
      );
    addVerboseFlag(parser);
    addJsonOutputFlag(parser);
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

    if (jsonOutputRequested(argResults!)) {
      writeJsonStdout({
        'count': devices.length,
        'devices': devicesToJson(devices),
        'sections': groupDevices(devices).map(
          (key, value) => MapEntry(key, devicesToJson(value)),
        ),
      });
      return 0;
    }

    if (devices.isEmpty) {
      logger.warn('No devices found.');
      return 0;
    }

    final verbose = argResults!['verbose'] == true;
    if (verbose) {
      logger.info(formatGroupedDeviceList(groupDevices(devices)));
      return 0;
    }

    for (final device in devices) {
      stdout.writeln(deviceDisplayName(device));
    }
    return 0;
  }
}
