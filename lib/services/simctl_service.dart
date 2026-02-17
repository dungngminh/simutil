import 'dart:convert';
import 'dart:io';

import '../models/device.dart';
import '../models/device_state.dart';
import '../models/device_type.dart';
import '../models/launch_options.dart';
import 'command_exec.dart';
import 'device_service.dart';

/// Service for interacting with iOS simulators via `xcrun simctl` (macOS only).
class SimctlService implements DeviceService {
  final CommandExec _exec;

  SimctlService(this._exec);

  @override
  /// Check if `xcrun simctl` is available (only works on macOS).
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
  Future<List<Device>> listDevices() => listSimulators();

  /// List all iOS simulators.
  Future<List<Device>> listSimulators() async {
    if (!Platform.isMacOS) return [];

    try {
      final result = await _exec.run(
        'xcrun',
        arguments: ['simctl', 'list', 'devices', '-j'],
      );
      if (!result.success) return [];

      final json = jsonDecode(result.stdout) as Map<String, dynamic>;
      final devicesMap = json['devices'] as Map<String, dynamic>? ?? {};
      final devices = <Device>[];

      for (final entry in devicesMap.entries) {
        final runtime =
            entry.key; // e.g., "com.apple.CoreSimulator.SimRuntime.iOS-17-2"
        final platformName = _extractPlatformName(runtime);
        final deviceList = entry.value as List<dynamic>;

        for (final d in deviceList) {
          final map = d as Map<String, dynamic>;
          if (map['isAvailable'] == true) {
            devices.add(
              Device(
                id: map['udid'] as String,
                name: map['name'] as String,
                type: DeviceType.ios,
                platform: platformName,
                state: DeviceState.fromString(
                  map['state'] as String? ?? 'Shutdown',
                ),
              ),
            );
          }
        }
      }

      return devices;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> launchDevice(String deviceId, LaunchOptions options) async {
    await bootSimulator(deviceId);
    await openSimulatorApp();
  }

  /// Boot an iOS simulator by UDID.
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

  /// Open the Simulator.app.
  Future<void> openSimulatorApp() async {
    await Process.start('open', [
      '-a',
      'Simulator',
    ], mode: ProcessStartMode.detached);
  }

  /// Shutdown an iOS simulator by UDID.
  Future<bool> shutdownSimulator(String udid) async {
    try {
      final result = await _exec.run(
        'xcrun',
        arguments: ['simctl', 'shutdown', udid],
      );
      return result.success;
    } catch (_) {
      return false;
    }
  }

  /// Extract a human-readable platform name from a runtime identifier.
  /// e.g., "com.apple.CoreSimulator.SimRuntime.iOS-17-2" -> "iOS 17.2"
  String _extractPlatformName(String runtime) {
    final parts = runtime.split('.');
    if (parts.isEmpty) return runtime;
    final last = parts.last; // e.g., "iOS-17-2"
    return last
        .replaceAll('-', ' ')
        .replaceFirstMapped(
          RegExp(r'(\w+)\s(\d.*)'),
          (m) => '${m[1]} ${m[2]?.replaceAll(' ', '.')}',
        );
  }
}
