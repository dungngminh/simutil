import 'dart:io';

import 'package:args/args.dart';
import 'package:simutil_cli/src/cli_device_services.dart';
import 'package:simutil_cli/src/cli_flags.dart';
import 'package:simutil_cli/src/cli_output.dart';
import 'package:simutil_cli/src/commands/simutil_command.dart';
import 'package:simutil_core/simutil_core.dart';

/// Shared list rendering for device commands.
abstract class DeviceListCommand extends SimutilCommand {
  /// Creates a list command with optional [services].
  DeviceListCommand({super.logger, CliDeviceServices? services})
    : deviceServices = services ?? CliDeviceServices();

  /// Device services used to query platforms.
  final CliDeviceServices deviceServices;

  /// Human-readable section title printed above results.
  String get sectionTitle;

  /// Device query for this list command.
  Future<List<Device>> fetchDevices(ArgResults args);

  @override
  ArgParser get argParser => configuredArgParser((parser) {
    addPlatformFlags(parser);
    parser.addFlag(
      'running',
      abbr: 'r',
      help: 'Show only running devices (-r, --running)',
      negatable: false,
    );
    addVerboseFlag(parser);
    addJsonOutputFlag(parser);
  });

  @override
  String get description => 'List $sectionTitle';

  @override
  Future<int> run() async {
    final devices = await fetchDevices(argResults!);

    if (jsonOutputRequested(argResults!)) {
      writeJsonStdout({
        'section': sectionTitle,
        'count': devices.length,
        'devices': devicesToJson(devices),
      });
      return 0;
    }

    if (devices.isEmpty) {
      logger.warn('No $sectionTitle found.');
      return 0;
    }

    final verbose = argResults!['verbose'] == true;
    if (verbose) {
      logger.info(formatDeviceListSection(sectionTitle, devices, verbose: true));
      return 0;
    }

    for (final device in devices) {
      stdout.writeln(deviceDisplayName(device));
    }
    return 0;
  }
}

/// Name shown in plain list mode (matches `android emulator list` style).
String deviceDisplayName(Device device) {
  if (device.type == DeviceType.simulator) {
    return device.name;
  }
  return '${device.name} (${device.id})';
}

/// Formats a labeled device section for verbose output.
String formatDeviceListSection(
  String title,
  List<Device> devices, {
  required bool verbose,
}) {
  final buffer = StringBuffer()..writeln(title);
  if (devices.isEmpty) {
    buffer.writeln('  (none)');
    return buffer.toString().trimRight();
  }

  if (!verbose) {
    for (final device in devices) {
      buffer.writeln('  ${deviceDisplayName(device)}');
    }
    return buffer.toString().trimRight();
  }

  buffer.writeln(
    formatCliTable(
      columns: deviceListColumns,
      rows: devices.map(deviceTableRow).toList(),
    ),
  );
  return buffer.toString().trimRight();
}

/// Formats multiple sections for `simutil list`.
String formatGroupedDeviceList(Map<String, List<Device>> sections) {
  final buffer = StringBuffer();
  var index = 0;
  for (final entry in sections.entries) {
    if (entry.value.isEmpty) continue;
    if (index++ > 0) buffer.writeln();
    buffer.write(
      formatDeviceListSection(entry.key, entry.value, verbose: true),
    );
  }
  return buffer.toString().trimRight();
}

/// Groups devices for the top-level list command.
Map<String, List<Device>> groupDevices(List<Device> devices) {
  final androidEmulators = <Device>[];
  final androidPhysical = <Device>[];
  final appleSimulators = <Device>[];
  final applePhysical = <Device>[];

  for (final device in devices) {
    switch ((device.os, device.type)) {
      case (DeviceOs.android, DeviceType.simulator):
        androidEmulators.add(device);
      case (DeviceOs.android, DeviceType.physical):
        androidPhysical.add(device);
      case (DeviceOs.ios, DeviceType.simulator):
        appleSimulators.add(device);
      case (DeviceOs.ios, DeviceType.physical):
        applePhysical.add(device);
    }
  }

  return {
    if (androidEmulators.isNotEmpty) 'Android emulators': androidEmulators,
    if (androidPhysical.isNotEmpty) 'Android devices': androidPhysical,
    if (appleSimulators.isNotEmpty) 'Apple simulators': appleSimulators,
    if (applePhysical.isNotEmpty) 'Apple devices': applePhysical,
  };
}
