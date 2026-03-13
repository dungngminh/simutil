import 'dart:convert';
import 'dart:io';

import 'package:simutil/models/device.dart';
import 'package:simutil/models/device_state.dart';
import 'package:simutil/models/device_type.dart';
import 'package:simutil/models/launch_options.dart';
import 'package:simutil/models/os.dart';

import 'package:simutil/services/command_exec.dart';
import 'package:simutil/services/device_service.dart';

class IOSDeviceService implements DeviceService {

  IOSDeviceService(this._exec);
  final CommandExec _exec;

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
  Future<List<Device>> listDevices() async {
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

      final json = jsonDecode(result.stdout) as Map<String, dynamic>;
      final devicesMap = json['devices'] as Map<String, dynamic>? ?? {};
      final devices = <Device>[];

      for (final entry in devicesMap.entries) {
        final runtime = entry.key;
        final platformName = _extractPlatformName(runtime);
        final deviceList = entry.value as List<dynamic>;

        for (final d in deviceList) {
          final map = d as Map<String, dynamic>;
          if (map['isAvailable'] == true) {
            devices.add(
              Device(
                id: map['udid'] as String,
                name: map['name'] as String,
                os: Os.ios,
                type: DeviceType.simulator,
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
    } catch (e, st) {
      print('IOSDeviceService._listSimulators error: $e\n$st');
      return [];
    }
  }

  @override
  Future<void> launchDevice(String deviceId, LaunchOptions options) async {
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

  Future<void> openSimulatorApp(String uuid) async {
    await _exec.run(
      'open',
      arguments: ['-a', 'Simulator', '--args', '-CurrentDeviceUDID', uuid],
    );
  }

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

  String _extractPlatformName(String runtime) {
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
}
