import 'dart:io';

import 'package:simutil/models/android_quick_launch_option.dart';
import 'package:simutil/models/device.dart';
import 'package:simutil/models/device_state.dart';
import 'package:simutil/models/device_type.dart';
import 'package:simutil/models/launch_options.dart';
import 'package:simutil/models/os.dart';

import 'command_exec.dart';
import 'device_service.dart';

/// Service for interacting with Android emulators via `adb` and `emulator` CLI.
///
/// Resolves tool paths through `$ANDROID_HOME` (or the default macOS SDK path)
/// following the same strategy as MiniSim.
class AndroidDeviceService implements DeviceService {
  final CommandExec _exec;

  AndroidDeviceService(this._exec);

  // ── Path helpers ──────────────────────────────────────────────

  /// Resolve `ANDROID_HOME`, falling back to `~/Library/Android/sdk` on macOS.
  String getAndroidHome() {
    final env =
        Platform.environment['ANDROID_HOME'] ??
        Platform.environment['ANDROID_SDK_ROOT'];
    if (env != null && env.isNotEmpty) return env;
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Library/Android/sdk';
  }

  /// Full path to the `adb` binary.
  String get adbPath => '${getAndroidHome()}/platform-tools/adb';

  /// Full path to the `emulator` binary.
  String get emulatorPath => '${getAndroidHome()}/emulator/emulator';

  // ── Availability ──────────────────────────────────────────────

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

  // ── List devices ──────────────────────────────────────────────

  @override
  Future<List<Device>> listDevices() => _listEmulators();

  /// List all Android emulators, checking which ones are currently running.
  ///
  /// All CLI calls go through [_exec], which is backed by the long-lived
  /// background isolate — no per-call isolate spawning needed.
  Future<List<Device>> _listEmulators() async {
    try {
      final result = await _exec.run(emulatorPath, arguments: ['-list-avds']);
      if (!result.success) return [];

      final avdNames = result.stdout
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      // Build a map of AVD name → emulator serial for running emulators.
      final runningMap = await _getRunningAvdMap();

      return avdNames.map((name) {
        return Device(
          id: name,
          name: name,
          os: Os.android,
          type: DeviceType.simulator,
          platform: 'Android',
          state: runningMap.containsKey(name)
              ? DeviceState.booted
              : DeviceState.shutdown, 
        );
      }).toList();
    } catch (e, st) {
      // ignore: avoid_print
      print('AndroidDeviceService._listEmulators error: $e\n$st');
      return [];
    }
  }

  /// Query every online `emulator-*` device for its AVD name.
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

      // Parallelize the lookup for each serial.
      await Future.wait(
        serials.map((serial) async {
          try {
            // `adb -s <serial> emu avd name` returns the AVD name on the
            // first line.
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
          } catch (_) {
            // Skip; this emulator might have disconnected.
          }
        }),
      );
      return map;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> launchDevice(String deviceId, LaunchOptions options) async {
    final args = ['@$deviceId', ...options.toAndroidArgs()];
    await _exec.run(emulatorPath, arguments: args);
  }

  /// Launch emulator with quick launch option preset.
  Future<void> launchWithQuickOption(
    String deviceId,
    AndroidQuickLaunchOption option,
  ) async {
    final args = ['@$deviceId', ...option.args];
    await _exec.run(emulatorPath, arguments: args);
  }

  // ── ADB Connect ────────────────────────────────────────────────

  /// Connect to a device via ADB over TCP/IP.
  ///
  /// [host] should be in format "ip:port" (e.g., "192.168.1.100:5555").
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

  /// Disconnect a device connected via TCP/IP.
  Future<bool> disconnectDevice(String host) async {
    try {
      final result = await _exec.run(adbPath, arguments: ['disconnect', host]);
      return result.success;
    } catch (_) {
      return false;
    }
  }

  /// Enable wireless debugging on a USB-connected device.
  ///
  /// This sets the device to listen on the specified [port] (default 5555).
  /// After this, you can disconnect USB and use [connectDevice] with the IP.
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

  /// Get the IP address of a connected device.
  ///
  /// Returns null if the IP cannot be determined.
  Future<String?> getDeviceIpAddress(String serial) async {
    try {
      // Try wlan0 first (most common for WiFi)
      final result = await _exec.run(
        adbPath,
        arguments: ['-s', serial, 'shell', 'ip', 'route'],
      );

      if (result.success) {
        // Parse "... src 192.168.x.x ..." from ip route output
        final match = RegExp(
          r'src\s+(\d+\.\d+\.\d+\.\d+)',
        ).firstMatch(result.stdout);
        if (match != null) {
          return match.group(1);
        }
      }

      // Fallback: try ifconfig
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

  /// Get pairing code info for wireless debugging (Android 11+).
  ///
  /// Returns the pairing port if wireless debugging is enabled.
  Future<WirelessPairingInfo?> getWirelessPairingInfo(String serial) async {
    try {
      // Check if device supports wireless debugging (Android 11+)
      final versionResult = await _exec.run(
        adbPath,
        arguments: ['-s', serial, 'shell', 'getprop', 'ro.build.version.sdk'],
      );

      if (!versionResult.success) return null;

      final sdkVersion = int.tryParse(versionResult.stdout.trim()) ?? 0;
      if (sdkVersion < 30) {
        return null; // Wireless debugging requires Android 11 (API 30)+
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

  /// Pair with a device using wireless debugging (Android 11+).
  ///
  /// [host] should be "ip:port" from the pairing dialog on device.
  /// [pairingCode] is the 6-digit code shown on device.
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
}

/// Result of an ADB connect/pair operation.
class AdbConnectResult {
  final bool success;
  final String message;

  const AdbConnectResult({required this.success, required this.message});
}

/// Information for wireless debugging pairing.
class WirelessPairingInfo {
  final String deviceIp;
  final int defaultPort;
  final bool supportsWirelessDebugging;

  const WirelessPairingInfo({
    required this.deviceIp,
    required this.defaultPort,
    required this.supportsWirelessDebugging,
  });
}
