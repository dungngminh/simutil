import 'dart:io';

import 'package:args/args.dart';
import 'package:simutil/src/cli/cli_device_services.dart';
import 'package:simutil/src/cli/cli_flags.dart';
import 'package:simutil/src/cli/commands/device_list_command.dart';
import 'package:simutil/src/cli/commands/simutil_command.dart';
import 'package:simutil_core/simutil_core.dart';

/// Parent for Android-specific CLI commands.
class AndroidCommand extends SimutilCommand {
  /// Creates the `android` command group.
  AndroidCommand({super.logger, CliDeviceServices? services}) {
    final resolved = services ?? CliDeviceServices();
    addSubcommand(AndroidEmulatorCommand(logger: logger, services: resolved));
    addSubcommand(AndroidDeviceCommand(logger: logger, services: resolved));
  }

  @override
  String get name => 'android';

  @override
  String get description => 'Android emulators and hardware';
}

/// `simutil android emulator …`
class AndroidEmulatorCommand extends SimutilCommand {
  /// Creates the `emulator` subgroup.
  AndroidEmulatorCommand({super.logger, required CliDeviceServices services}) {
    addSubcommand(
      AndroidEmulatorListCommand(logger: logger, services: services),
    );
  }

  @override
  String get name => 'emulator';

  @override
  String get description => 'Android Virtual Devices (AVD)';
}

/// `simutil android emulator list`
class AndroidEmulatorListCommand extends DeviceListCommand {
  /// Creates the list subcommand.
  AndroidEmulatorListCommand({super.logger, super.services});

  @override
  String get name => 'list';

  @override
  String get sectionTitle => 'Android emulators';

  @override
  String get usage => catalogUsage(
    'android',
    'simutil android emulator list [options]',
    path: ['emulator', 'list'],
  );

  @override
  Future<List<Device>> fetchDevices(ArgResults args) =>
      deviceServices.listDevices(
        android: true,
        ios: false,
        emulator: true,
        physical: false,
        runningOnly: args['running'] == true,
      );
}

/// `simutil android device …`
class AndroidDeviceCommand extends SimutilCommand {
  /// Creates the `device` subgroup.
  AndroidDeviceCommand({super.logger, required CliDeviceServices services}) {
    addSubcommand(AndroidDeviceListCommand(logger: logger, services: services));
  }

  @override
  String get name => 'device';

  @override
  String get description => 'Connected Android hardware (adb)';
}

/// `simutil android device list`
class AndroidDeviceListCommand extends DeviceListCommand {
  /// Creates the list subcommand.
  AndroidDeviceListCommand({super.logger, super.services});

  @override
  String get name => 'list';

  @override
  String get sectionTitle => 'Android devices';

  @override
  String get usage => catalogUsage(
    'android',
    'simutil android device list [options]',
    path: ['device', 'list'],
  );

  @override
  Future<List<Device>> fetchDevices(ArgResults args) =>
      deviceServices.listDevices(
        android: true,
        ios: false,
        emulator: false,
        physical: true,
        runningOnly: args['running'] == true,
      );
}

/// Parent for Apple-specific CLI commands (macOS).
class IosCommand extends SimutilCommand {
  /// Creates the `ios` command group.
  IosCommand({super.logger, CliDeviceServices? services}) {
    if (!Platform.isMacOS) return;
    final resolved = services ?? CliDeviceServices();
    addSubcommand(IosSimulatorCommand(logger: logger, services: resolved));
    addSubcommand(IosDeviceCommand(logger: logger, services: resolved));
  }

  @override
  String get name => 'ios';

  @override
  String get description => 'Apple simulators and hardware (macOS)';
}

/// `simutil ios simulator …`
class IosSimulatorCommand extends SimutilCommand {
  /// Creates the `simulator` subgroup.
  IosSimulatorCommand({super.logger, required CliDeviceServices services}) {
    addSubcommand(IosSimulatorListCommand(logger: logger, services: services));
  }

  @override
  String get name => 'simulator';

  @override
  String get description => 'CoreSimulator runtimes';
}

/// `simutil ios simulator list`
class IosSimulatorListCommand extends DeviceListCommand {
  /// Creates the list subcommand.
  IosSimulatorListCommand({super.logger, super.services});

  @override
  String get name => 'list';

  @override
  String get sectionTitle => 'Apple simulators';

  @override
  Future<List<Device>> fetchDevices(ArgResults args) =>
      deviceServices.listDevices(
        android: false,
        ios: true,
        emulator: true,
        physical: false,
        runningOnly: args['running'] == true,
      );
}

/// `simutil ios device …`
class IosDeviceCommand extends SimutilCommand {
  /// Creates the `device` subgroup.
  IosDeviceCommand({super.logger, required CliDeviceServices services}) {
    addSubcommand(IosDeviceListCommand(logger: logger, services: services));
  }

  @override
  String get name => 'device';

  @override
  String get description => 'Connected Apple hardware (devicectl)';
}

/// `simutil ios device list`
class IosDeviceListCommand extends DeviceListCommand {
  /// Creates the list subcommand.
  IosDeviceListCommand({super.logger, super.services});

  @override
  String get name => 'list';

  @override
  String get sectionTitle => 'Apple devices';

  @override
  Future<List<Device>> fetchDevices(ArgResults args) =>
      deviceServices.listDevices(
        android: false,
        ios: true,
        emulator: false,
        physical: true,
        runningOnly: args['running'] == true,
      );
}
