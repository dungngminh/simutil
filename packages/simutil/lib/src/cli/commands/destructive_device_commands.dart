import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:simutil/src/cli/cli_device_services.dart';
import 'package:simutil/src/cli/cli_flags.dart';
import 'package:simutil/src/cli/commands/simutil_command.dart';
import 'package:simutil_core/simutil_core.dart';

/// Shared flow for commands that destroy a shut-down emulator / simulator's
/// data: resolve the id, refuse physical or running devices, ask y/N unless
/// `--yes`, then run [perform].
abstract class _DestructiveDeviceCommand extends SimutilCommand {
  _DestructiveDeviceCommand({super.logger, CliDeviceServices? services})
    : services = services ?? CliDeviceServices();

  final CliDeviceServices services;

  /// Verb for messages, e.g. `wipe`.
  String get verb;

  /// Past tense for the success message, e.g. `Wiped`.
  String get done;

  /// The y/N prompt for [device].
  String prompt(Device device);

  /// Runs the action; returns whether it succeeded.
  Future<bool> perform(Device device);

  @override
  ArgParser get argParser => configuredArgParser((parser) {
    addPlatformFlags(parser);
    parser.addFlag(
      'yes',
      abbr: 'y',
      help: 'Skip the confirmation prompt (-y, --yes)',
      negatable: false,
    );
  });

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      throw UsageException('Missing device id.', usage);
    }
    if (rest.length > 1) {
      throw UsageException('Expected a single device id.', usage);
    }

    final device = await services.resolveDevice(
      rest.first,
      osHint: osHintFromFlags(argResults!),
    );
    final label = '${device.name} (${device.id})';
    if (device.type.isPhysical) {
      logger.err('Cannot $verb physical device $label');
      return 1;
    }
    if (device.isRunning) {
      logger.err(
        '$label is running. Shut it down first: simutil shutdown ${device.id}',
      );
      return 1;
    }

    if (argResults!['yes'] != true && !logger.confirm(prompt(device))) {
      logger.info('Cancelled');
      return 1;
    }

    if (!await perform(device)) {
      logger.err('Failed to $verb $label');
      return 1;
    }
    logger.success('$done $label');
    return 0;
  }
}

/// Erases a shut-down emulator or simulator's data.
class WipeCommand extends _DestructiveDeviceCommand {
  /// Creates the `wipe` subcommand.
  WipeCommand({super.logger, super.services});

  @override
  String get name => 'wipe';

  @override
  String get description => 'Wipe an emulator or simulator\'s data by id';

  @override
  String get verb => 'wipe';

  @override
  String get done => 'Wiped';

  @override
  String prompt(Device device) =>
      'Erase all apps, settings and snapshots of ${device.name}? '
      'This cannot be undone.';

  @override
  Future<bool> perform(Device device) => services.wipeDevice(device);
}

/// Permanently deletes a shut-down emulator or simulator.
class DeleteCommand extends _DestructiveDeviceCommand {
  /// Creates the `delete` subcommand.
  DeleteCommand({super.logger, super.services});

  @override
  String get name => 'delete';

  @override
  String get description => 'Delete an emulator or simulator by id';

  @override
  String get verb => 'delete';

  @override
  String get done => 'Deleted';

  @override
  String prompt(Device device) =>
      'Delete ${device.name} and all of its data? This cannot be undone.';

  @override
  Future<bool> perform(Device device) => services.deleteDevice(device);
}
