import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:simutil/models/device.dart';
import 'package:simutil/models/device_state.dart';
import 'package:simutil/models/device_type.dart';
import 'package:simutil/services/command_exec.dart';
import 'package:simutil/services/device_service.dart';

class IOSDeviceService implements DeviceService {
  const IOSDeviceService(this._exec);

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
    } catch (e, st) {
      log('IOSDeviceService._listSimulators error: $e\n$st');
      return [];
    }
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

  Future<void> openSimulatorApp(String uuid) async {
    await _exec.run(
      'open',
      arguments: ['-a', 'Simulator', '--args', '-CurrentDeviceUDID', uuid],
    );
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

  @override
  Future<List<Device>> getPhysicalDevices() async {
    if (!Platform.isMacOS) return [];

    final tempDirectory = Directory.systemTemp;
    final outputFile = File('${tempDirectory.path}/ios_devices.json');

    try {
      final devicectl = await _exec.run(
        'xcrun',
        arguments: ['devicectl', 'list', 'devices', '-j', outputFile.path],
      );

      if (!devicectl.success) return [];

      final json =
          jsonDecode(await outputFile.readAsString()) as Map<String, dynamic>;

      return _parsePhysicalDevices(json);
    } catch (e, st) {
      log('IOSDeviceService.getPhysicalDevices error: $e\n$st');
      return [];
    } finally {
      if (outputFile.existsSync()) {
        outputFile.deleteSync();
      }
    }
  }

  List<Device> _parsePhysicalDevices(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>? ?? {};
    final deviceList = result['devices'] as List<dynamic>? ?? [];

    final devices = <Device>[];

    for (final d in deviceList) {
      final map = d as Map<String, dynamic>;
      final deviceProps =
          map['deviceProperties'] as Map<String, dynamic>? ?? {};
      final identifier = map['identifier'] as String? ?? '';
      final name = deviceProps['name'] as String? ?? '';
      final osVersion = deviceProps['osVersionNumber'] as String? ?? '';
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
}
