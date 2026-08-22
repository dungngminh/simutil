import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:simutil/cli/cli_device_services.dart';
import 'package:simutil/cli/commands/simutil_command.dart';

/// Boots an emulator or simulator by device id.
class LaunchCommand extends SimutilCommand {
  /// Creates the `launch` subcommand.
  LaunchCommand({super.logger, CliDeviceServices? services})
    : _services = services ?? CliDeviceServices();

  final CliDeviceServices _services;

  @override
  String get name => 'launch';

  @override
  List<String> get aliases => const ['start'];

  @override
  String get description => 'Launch a device by id';

  @override
  ArgParser get argParser {
    final parser = super.argParser;
    addPlatformFlags(parser);
    parser
      ..addFlag(
        'cold',
        abbr: 'c',
        help: 'Cold boot (Android: -no-snapshot-load).',
        negatable: false,
      )
      ..addFlag(
        'no-audio',
        help: 'Disable emulator audio (Android).',
        negatable: false,
      );
    return parser;
  }

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

    await _services.launchDevice(
      device,
      cold: argResults!['cold'] == true,
      noAudio: argResults!['no-audio'] == true,
    );

    logger.success('Launched ${device.name} (${device.id})');
    return 0;
  }
}
