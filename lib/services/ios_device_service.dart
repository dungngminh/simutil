import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:simutil/models/device.dart';
import 'package:simutil/models/device_state.dart';
import 'package:simutil/models/device_type.dart';
import 'package:simutil/services/command_exec.dart';
import 'package:simutil/services/device_service.dart';

class IOSDeviceService implements DeviceService {
  IOSDeviceService(this._exec, {bool Function(String path)? pathExists})
    : _pathExists = pathExists ?? _directoryExists;

  final CommandExec _exec;
  final bool Function(String path) _pathExists;

  static bool _directoryExists(String path) => Directory(path).existsSync();

  @override
  Future<bool> isAvailable() async {
    if (!Platform.isMacOS) return false;
    try {
      final result = await _exec.run(
        'xcrun',
        arguments: ['simctl', 'list', '--json'],
      );
      return result.success;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<Device>> getSimulators() async {
    if (!Platform.isMacOS) return [];
    return _listSimulators();
  }

  Future<List<Device>> _listSimulators() async {
    try {
      final result = await _exec.run(
        'xcrun',
        arguments: ['simctl', 'list', 'devices', '-j'],
      );
      if (!result.success) return [];

      return parseSimulators(result.stdout);
    } catch (e, st) {
      log('IOSDeviceService._listSimulators error: $e\n$st');
      return [];
    }
  }

  /// Parses the JSON output of `xcrun simctl list devices -j` into devices.
  /// Pure function (no I/O) so it is unit-testable on any platform.
  static List<Device> parseSimulators(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final devicesMap = json['devices'] as Map<String, dynamic>? ?? {};
    final devices = <Device>[];

    for (final entry in devicesMap.entries) {
      final runtime = entry.key;
      final platformName = extractPlatformName(runtime);
      final deviceList = entry.value as List<dynamic>;

      for (final d in deviceList) {
        final map = d as Map<String, dynamic>;
        if (map['isAvailable'] == true) {
          devices.add(
            Device.ios(
              id: map['udid'] as String,
              name: map['name'] as String,
              platform: platformName,
              type: DeviceType.simulator,
              state: DeviceState.fromString(
                map['state'] as String? ?? DeviceState.shutdown.label,
              ),
            ),
          );
        }
      }
    }

    return devices;
  }

  @override
  Future<void> launchDevice({
    required String deviceId,
    List<String> additionalArgs = const [],
  }) async {
    await bootSimulator(deviceId);
    await openSimulatorApp(deviceId);
  }

  Future<bool> bootSimulator(String udid) async {
    try {
      final result = await _exec.run(
        'xcrun',
        arguments: ['simctl', 'boot', udid],
      );
      return result.success;
    } catch (_) {
      return false;
    }
  }

  /// Opens the simulator UI focused on [uuid].
  ///
  /// Xcode 27+ replaced Simulator.app with DeviceHub.app
  /// (`<Xcode.app>/Contents/Applications/DeviceHub.app`). Older Xcodes still
  /// ship Simulator.app under `Contents/Developer/Applications`. Same lookup
  /// as Flutter's `Xcode.getSimulatorPath` (flutter/flutter#187910).
  Future<void> openSimulatorApp(String uuid) async {
    final developerPath = await _xcodeDeveloperPath();
    final appPath = resolveSimulatorAppPath(
      developerPath: developerPath,
      exists: _pathExists,
    );
    await _exec.run(
      'open',
      arguments: openSimulatorArguments(uuid: uuid, appPath: appPath),
    );
  }

  Future<String?> _xcodeDeveloperPath() async {
    try {
      final result = await _exec.run(
        '/usr/bin/xcode-select',
        arguments: ['--print-path'],
      );
      if (!result.success) return null;
      final path = result.stdout.trim();
      return path.isEmpty ? null : path;
    } catch (_) {
      return null;
    }
  }

  /// Prefer DeviceHub.app (Xcode 27+), then Simulator.app.
  ///
  /// [developerPath] is `xcode-select -p` (for example
  /// `/Applications/Xcode.app/Contents/Developer`).
  static String? resolveSimulatorAppPath({
    required String? developerPath,
    required bool Function(String path) exists,
  }) {
    if (developerPath == null || developerPath.isEmpty) return null;
    final deviceHub = p.posix.join(
      p.posix.dirname(developerPath),
      'Applications',
      'DeviceHub.app',
    );
    if (exists(deviceHub)) return deviceHub;
    final simulator = p.posix.join(
      developerPath,
      'Applications',
      'Simulator.app',
    );
    if (exists(simulator)) return simulator;
    return null;
  }

  /// `open` arguments for [appPath].
  ///
  /// Simulator.app focuses a device with `-CurrentDeviceUDID`. DeviceHub.app
  /// does not take that flag; `simctl boot` already selected the device.
  static List<String> openSimulatorArguments({
    required String uuid,
    required String? appPath,
  }) {
    final app = appPath ?? 'Simulator';
    final args = <String>['-a', app];
    final isDeviceHub =
        appPath != null && p.posix.basename(appPath) == 'DeviceHub.app';
    if (!isDeviceHub) {
      args.addAll(['--args', '-CurrentDeviceUDID', uuid]);
    }
    return args;
  }

  @override
  Future<bool> shutdownSimulator({required String deviceId}) async {
    try {
      final result = await _exec.run(
        'xcrun',
        arguments: ['simctl', 'shutdown', deviceId],
      );
      return result.success;
    } catch (_) {
      return false;
    }
  }

  /// Derives a human-readable platform name from a simctl runtime key, e.g.
  /// `com.apple.CoreSimulator.SimRuntime.iOS-17-2` -> `iOS 17.2`.
  static String extractPlatformName(String runtime) {
    final parts = runtime.split('.');
    if (parts.isEmpty) return runtime;
    final last = parts.last;
    return last
        .replaceAll('-', ' ')
        .replaceFirstMapped(
          RegExp(r'(\w+)\s(\d.*)'),
          (m) => '${m[1]} ${m[2]?.replaceAll(' ', '.')}',
        );
  }

  @override
  Future<List<Device>> getPhysicalDevices() async {
    if (!Platform.isMacOS) return [];

    final tempDirectory = Directory.systemTemp;
    final outputFile = File('${tempDirectory.path}/ios_devices.json');

    try {
      final devicectl = await _exec.run(
        'xcrun',
        arguments: [
          'devicectl',
          'list',
          'devices',
          '--filter',
          "Reality = 'physical'",
          '-j',
          outputFile.path,
        ],
      );

      if (!devicectl.success) return [];

      final json =
          jsonDecode(await outputFile.readAsString()) as Map<String, dynamic>;

      return parsePhysicalDevices(json);
    } catch (e, st) {
      log('IOSDeviceService.getPhysicalDevices error: $e\n$st');
      return [];
    } finally {
      if (outputFile.existsSync()) {
        outputFile.deleteSync();
      }
    }
  }

  /// Parses the JSON written by `xcrun devicectl list devices -j` into devices.
  /// Pure function (no I/O) so it is unit-testable on any platform.
  static List<Device> parsePhysicalDevices(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>? ?? {};
    final deviceList = result['devices'] as List<dynamic>? ?? [];

    final devices = <Device>[];

    for (final d in deviceList) {
      final map = d as Map<String, dynamic>;
      final deviceProps =
          map['deviceProperties'] as Map<String, dynamic>? ?? {};
      final connectionProps =
          map['connectionProperties'] as Map<String, dynamic>? ?? {};
      final identifier = map['identifier'] as String? ?? '';
      final name = deviceProps['name'] as String? ?? '';
      final osVersion = deviceProps['osVersionNumber'] as String? ?? '';
      if (_deviceReality(map) == 'simulated') continue;
      final tunnelState = connectionProps['tunnelState'] as String?;
      final isConnected = ![
        'unavailable',
        'disconnected',
      ].contains(tunnelState);
      if (!isConnected) continue;
      devices.add(
        Device.ios(
          id: identifier,
          name: name,
          platform: 'iOS $osVersion',
          type: DeviceType.physical,
          state: DeviceState.booted,
        ),
      );
    }

    return devices;
  }

  /// `simulated` or `physical` from `devicectl` JSON.
  ///
  /// Xcode 27 reports simulators in `devicectl list devices`. Booted ones have
  /// `tunnelState: connected`, so connection state alone is not enough.
  static String? _deviceReality(Map<String, dynamic> device) {
    final hardware = device['hardwareProperties'] as Map<String, dynamic>?;
    final fromHardware = hardware?['reality'] as String?;
    if (fromHardware != null && fromHardware.isNotEmpty) return fromHardware;

    final properties = device['properties'] as Map<String, dynamic>?;
    final nestedHardware = properties?['hardware'] as Map<String, dynamic>?;
    final fromProperties = nestedHardware?['reality'] as String?;
    if (fromProperties != null && fromProperties.isNotEmpty) {
      return fromProperties;
    }
    return null;
  }
}
