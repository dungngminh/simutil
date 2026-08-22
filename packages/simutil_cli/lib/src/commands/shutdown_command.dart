import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:simutil_cli/src/cli_device_services.dart';
import 'package:simutil_cli/src/cli_flags.dart';
import 'package:simutil_cli/src/commands/simutil_command.dart';

/// Shuts down a running emulator or simulator.
class ShutdownCommand extends SimutilCommand {
  /// Creates the `shutdown` subcommand.
  ShutdownCommand({super.logger, CliDeviceServices? services})
    : _services = services ?? CliDeviceServices();

  final CliDeviceServices _services;

  @override
  String get name => 'shutdown';

  @override
  List<String> get aliases => const ['stop'];

  @override
  String get description => 'Shut down a device by id';

  @override
  ArgParser get argParser =>
      configuredArgParser(addPlatformFlags);

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      throw UsageException('Missing device id.', usage);
    }
    if (rest.length > 1) {
      throw UsageException('Expected a single device id.', usage);
    }

    final device = await _services.resolveDevice(
      rest.first,
      osHint: osHintFromFlags(argResults!),
    );

    final ok = await _services.shutdownDevice(device);
    if (!ok) {
      logger.err('Failed to shut down ${device.name} (${device.id})');
      return 1;
    }

    logger.success('Shut down ${device.name} (${device.id})');
    return 0;
  }
}
