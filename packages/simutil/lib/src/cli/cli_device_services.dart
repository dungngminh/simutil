import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_apple/simutil_apple.dart';
import 'package:simutil_core/simutil_core.dart';

/// Headless device services for CLI commands.
class CliDeviceServices {
  /// Creates services keyed by [DeviceOs].
  ///
  /// Defaults to adb and simctl services backed by a synchronous
  /// `CommandExec()`; pass [services] to inject fakes in tests.
  CliDeviceServices({Map<DeviceOs, DeviceService>? services})
    : _services = services ?? _defaultServices(CommandExec());

  final Map<DeviceOs, DeviceService> _services;

  static Map<DeviceOs, DeviceService> _defaultServices(CommandExec exec) => {
    DeviceOs.android: AndroidDeviceService(exec),
    DeviceOs.ios: IOSDeviceService(exec),
  };

  /// Lists devices with optional platform/type/state filters.
  Future<List<Device>> listDevices({
    bool android = true,
    bool ios = true,
    bool emulator = true,
    bool physical = true,
    bool runningOnly = false,
  }) async {
    final devices = <Device>[];
    for (final MapEntry(key: os, value: service) in _services.entries) {
      if (os == DeviceOs.android && !android) continue;
      if (os == DeviceOs.ios && (!ios || !Platform.isMacOS)) continue;
      if (emulator) devices.addAll(await service.getSimulators());
      if (physical) devices.addAll(await service.getPhysicalDevices());
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
      cliUsage('Ambiguous device id "$id". Use -a/--android or -i/--ios.');
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

    await _serviceFor(
      device,
    ).launchDevice(deviceId: device.id, additionalArgs: extra);
  }

  /// Shuts down [device] when it is a simulator/emulator.
  Future<bool> shutdownDevice(Device device) =>
      _serviceFor(device).shutdownSimulator(deviceId: device.id);

  DeviceService _serviceFor(Device device) =>
      _services[device.os] ??
      cliUsage('No service registered for ${device.os.name}');
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
