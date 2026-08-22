import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_apple/simutil_apple.dart';
import 'package:simutil_core/simutil_core.dart';

/// Headless device services for CLI commands using [CommandExecImpl].
class CliDeviceServices {
  /// Creates services backed by a synchronous [CommandExecImpl].
  CliDeviceServices({CommandExec? commandExec}) {
    final resolved = commandExec ?? CommandExecImpl();
    exec = resolved;
    adb = AndroidDeviceService(resolved);
    apple = IOSDeviceService(resolved);
  }

  /// Shell executor for adb and xcrun probes.
  late final CommandExec exec;

  /// Android emulators and hardware.
  late final AndroidDeviceService adb;

  /// Apple simulators and hardware (macOS only).
  late final IOSDeviceService apple;

  /// Lists devices with optional platform/type/state filters.
  Future<List<Device>> listDevices({
    bool android = true,
    bool ios = true,
    bool emulator = true,
    bool physical = true,
    bool runningOnly = false,
  }) async {
    final devices = <Device>[];
    if (android) {
      if (emulator) {
        devices.addAll(await adb.getSimulators());
      }
      if (physical) {
        devices.addAll(await adb.getPhysicalDevices());
      }
    }
    if (ios && Platform.isMacOS) {
      if (emulator) {
        devices.addAll(await apple.getSimulators());
      }
      if (physical) {
        devices.addAll(await apple.getPhysicalDevices());
      }
    }
    if (runningOnly) {
      return devices.where((d) => d.isRunning).toList();
    }
    return devices;
  }

  /// Resolves [id] to a single [Device], using [osHint] when ids collide.
  Future<Device> resolveDevice(String id, {DeviceOs? osHint}) async {
    final matches = (await listDevices()).where((d) => d.id == id).toList();
    if (matches.isEmpty) {
      cliUsage('Device not found: $id');
    }
    if (osHint != null) {
      final filtered = matches.where((d) => d.os == osHint).toList();
      if (filtered.isEmpty) {
        cliUsage('No ${osHint.name} device with id "$id"');
      }
      return filtered.first;
    }
    if (matches.length > 1) {
      cliUsage(
        'Ambiguous device id "$id". Use -a/--android or -i/--ios.',
      );
    }
    return matches.first;
  }

  /// Launches [device], optionally with Android cold boot / no-audio flags.
  Future<void> launchDevice(
    Device device, {
    bool cold = false,
    bool noAudio = false,
  }) async {
    final extra = <String>[];
    if (cold) extra.add('-no-snapshot-load');
    if (noAudio) extra.add('-no-audio');

    switch (device.os) {
      case DeviceOs.android:
        await adb.launchDevice(
          deviceId: device.id,
          additionalArgs: extra,
        );
      case DeviceOs.ios:
        await apple.launchDevice(
          deviceId: device.id,
          additionalArgs: extra,
        );
    }
  }

  /// Shuts down [device] when it is a simulator/emulator.
  Future<bool> shutdownDevice(Device device) {
    switch (device.os) {
      case DeviceOs.android:
        return adb.shutdownSimulator(deviceId: device.id);
      case DeviceOs.ios:
        return apple.shutdownSimulator(deviceId: device.id);
    }
  }
}

/// Throws [UsageException] for invalid CLI input outside a [Command].
Never cliUsage(String message) => throw UsageException(message, '');

/// Parses `-a`/`-i` flags into an optional [DeviceOs] hint.
DeviceOs? osHintFromFlags(ArgResults results) {
  final android = results['android'] == true;
  final ios = results['ios'] == true;
  if (android && ios) {
    cliUsage('Use only one of -a/--android or -i/--ios.');
  }
  if (android) return DeviceOs.android;
  if (ios) return DeviceOs.ios;
  return null;
}

/// Shared `-a` / `-i` platform flags for device commands.
void addPlatformFlags(ArgParser parser) {
  parser
    ..addFlag(
      'android',
      abbr: 'a',
      help: 'Limit to Android devices.',
      negatable: false,
    )
    ..addFlag(
      'ios',
      abbr: 'i',
      help: 'Limit to Apple devices.',
      negatable: false,
    );
}
