import 'dart:developer';
import 'dart:io';

import 'package:simutil/models/device.dart';
import 'package:simutil/models/device_state.dart';
import 'package:simutil/models/device_type.dart';
import 'package:simutil/models/device_os.dart';
import 'package:simutil/services/command_exec.dart';
import 'package:simutil/services/device_service.dart';

class AndroidDeviceService implements DeviceService {
  AndroidDeviceService(this._exec);
  final CommandExec _exec;

  String getAndroidHome() {
    final env =
        Platform.environment['ANDROID_HOME'] ??
        Platform.environment['ANDROID_SDK_ROOT'];
    if (env != null && env.isNotEmpty) return env;
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Library/Android/sdk';
  }

  String get adbPath => '${getAndroidHome()}/platform-tools/adb';

  String get emulatorPath => '${getAndroidHome()}/emulator/emulator';

  @override
  Future<bool> isAvailable() async {
    try {
      final adbOk = await _exec.run(adbPath, arguments: ['version']);
      final emuOk = await _exec.run(emulatorPath, arguments: ['-list-avds']);
      return adbOk.success && emuOk.success;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<Device>> getSimulators() => _listEmulators();

  Future<List<Device>> _listEmulators() async {
    try {
      final result = await _exec.run(emulatorPath, arguments: ['-list-avds']);
      if (!result.success) return [];

      final avdNames = result.stdout
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      final runningMap = await _getRunningAvdMap();

      return avdNames.map((name) {
        return Device(
          id: name,
          name: name,
          os: DeviceOs.android,
          type: DeviceType.simulator,
          platform: 'Android',
          state: runningMap.containsKey(name)
              ? DeviceState.booted
              : DeviceState.shutdown,
        );
      }).toList();
    } catch (e, st) {
      log('AndroidDeviceService._listEmulators error: $e\n$st');
      return [];
    }
  }

  Future<Map<String, String>> _getRunningAvdMap() async {
    try {
      final result = await _exec.run(adbPath, arguments: ['devices']);
      if (!result.success) return {};

      final serials = result.stdout
          .split('\n')
          .skip(1)
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && l.contains('device'))
          .map((l) => l.split('\t').first)
          .where((s) => s.startsWith('emulator-'))
          .toList();

      final map = <String, String>{};

      await Future.wait(
        serials.map((serial) async {
          try {
            final nameResult = await _exec.run(
              adbPath,
              arguments: ['-s', serial, 'emu', 'avd', 'name'],
            );
            if (nameResult.success) {
              final name = nameResult.stdout.split('\n').first.trim();
              if (name.isNotEmpty) {
                map[name] = serial;
              }
            }
          } catch (_) {}
        }),
      );
      return map;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> launchDevice({
    required String deviceId,
    List<String> additionalArgs = const [],
  }) async {
    final launchArgs = ['@$deviceId', ...additionalArgs];
    await _exec.run(emulatorPath, arguments: launchArgs);
  }

  Future<AdbConnectResult> connectDevice(String host) async {
    try {
      final result = await _exec.run(adbPath, arguments: ['connect', host]);
      final output = result.stdout.trim();

      if (output.contains('connected to') ||
          output.contains('already connected')) {
        return AdbConnectResult(success: true, message: output);
      }
      return AdbConnectResult(
        success: false,
        message: result.stderr.isNotEmpty ? result.stderr : output,
      );
    } catch (e) {
      return AdbConnectResult(success: false, message: e.toString());
    }
  }

  Future<bool> disconnectDevice(String host) async {
    try {
      final result = await _exec.run(adbPath, arguments: ['disconnect', host]);
      return result.success;
    } catch (_) {
      return false;
    }
  }

  Future<bool> enableTcpIp(String serial, {int port = 5555}) async {
    try {
      final result = await _exec.run(
        adbPath,
        arguments: ['-s', serial, 'tcpip', port.toString()],
      );
      return result.success;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getDeviceIpAddress(String serial) async {
    try {
      final result = await _exec.run(
        adbPath,
        arguments: ['-s', serial, 'shell', 'ip', 'route'],
      );

      if (result.success) {
        final match = RegExp(
          r'src\s+(\d+\.\d+\.\d+\.\d+)',
        ).firstMatch(result.stdout);
        if (match != null) {
          return match.group(1);
        }
      }

      final ifconfig = await _exec.run(
        adbPath,
        arguments: ['-s', serial, 'shell', 'ifconfig', 'wlan0'],
      );

      if (ifconfig.success) {
        final match = RegExp(
          r'inet addr:(\d+\.\d+\.\d+\.\d+)',
        ).firstMatch(ifconfig.stdout);
        if (match != null) {
          return match.group(1);
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<WirelessPairingInfo?> getWirelessPairingInfo(String serial) async {
    try {
      final versionResult = await _exec.run(
        adbPath,
        arguments: ['-s', serial, 'shell', 'getprop', 'ro.build.version.sdk'],
      );

      if (!versionResult.success) return null;

      final sdkVersion = int.tryParse(versionResult.stdout.trim()) ?? 0;
      if (sdkVersion < 30) {
        return null;
      }

      final ip = await getDeviceIpAddress(serial);
      if (ip == null) return null;

      return WirelessPairingInfo(
        deviceIp: ip,
        defaultPort: 5555,
        supportsWirelessDebugging: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<AdbConnectResult> pairDevice(String host, String pairingCode) async {
    try {
      final result = await _exec.run(
        adbPath,
        arguments: ['pair', host, pairingCode],
      );

      final output = result.stdout.trim();
      if (output.contains('Successfully paired') || result.success) {
        return AdbConnectResult(success: true, message: output);
      }
      return AdbConnectResult(
        success: false,
        message: result.stderr.isNotEmpty ? result.stderr : output,
      );
    } catch (e) {
      return AdbConnectResult(success: false, message: e.toString());
    }
  }

  @override
  Future<List<Device>> getPhysicalDevices() async {
    try {
      final result = await _exec.run(adbPath, arguments: ['devices', '-l']);
      if (!result.success) return [];

      final stdout = result.stdout;

      final rawDevices = stdout
          .split('\n')
          .skip(1)
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('emulator-'));

      return rawDevices
          .map((line) {
            final parts = line.split(RegExp(r'\s+'));
            final id = parts.isNotEmpty ? parts.first : '';

            var name = id;
            for (final part in parts) {
              if (part.startsWith('model:')) {
                name = part.substring(6).replaceAll('_', ' ');
                break;
              }
            }

            return Device.android(
              id: id,
              name: name,
              type: DeviceType.physical,
              state: DeviceState.booted,
            );
          })
          .where((d) => d.id.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }
}

class AdbConnectResult {
  const AdbConnectResult({required this.success, required this.message});
  final bool success;
  final String message;
}

class WirelessPairingInfo {
  const WirelessPairingInfo({
    required this.deviceIp,
    required this.defaultPort,
    required this.supportsWirelessDebugging,
  });
  final String deviceIp;
  final int defaultPort;
  final bool supportsWirelessDebugging;
}
