import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:simutil/src/cli/cli_device_services.dart';
import 'package:simutil/src/cli/cli_flags.dart';
import 'package:simutil/src/cli/commands/simutil_command.dart';
import 'package:simutil_adb/simutil_adb.dart';

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
  ArgParser get argParser => configuredArgParser((parser) {
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
      )
      ..addOption(
        'camera-back',
        help:
            'Android back camera: webcam<N>, image:<path>, video:<path>, '
            'virtualscene, emulated or none.',
        valueHelp: 'source',
      )
      ..addOption(
        'camera-front',
        help: 'Android front camera (same sources as --camera-back).',
        valueHelp: 'source',
      )
      ..addFlag(
        'headless',
        help: 'Start without the emulator window / Simulator app.',
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

    final List<String> cameraArgs;
    try {
      cameraArgs = emulatorCameraArgs(
        back: argResults!['camera-back'] as String?,
        front: argResults!['camera-front'] as String?,
      );
    } on FormatException catch (e) {
      throw UsageException(e.message, usage);
    }

    final device = await _services.resolveDevice(
      rest.first,
      osHint: osHintFromFlags(argResults!),
    );

    await _services.launchDevice(
      device,
      cold: argResults!['cold'] == true,
      noAudio: argResults!['no-audio'] == true,
      headless: argResults!['headless'] == true,
      cameraArgs: cameraArgs,
    );

    logger.success('Launched ${device.name} (${device.id})');
    return 0;
  }
}
