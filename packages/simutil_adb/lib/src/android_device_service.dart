import 'dart:developer';
import 'dart:io';

import 'package:simutil_adb/src/models/adb_connect_result.dart';
import 'package:simutil_adb/src/models/wireless_pairing_info.dart';
import 'package:simutil_core/simutil_core.dart';

/// Android emulators and hardware devices via `adb` and the SDK emulator.
class AndroidDeviceService implements DeviceService {
  /// Creates a service using [CommandExec] for all shell work.
  ///
  /// [androidHomeOverride] wins over `ANDROID_HOME` / `ANDROID_SDK_ROOT`.
  /// [environment], [fileExists] and [isWindows] are test seams.
  AndroidDeviceService(
    this._exec, {
    String? androidHomeOverride,
    Map<String, String>? environment,
    bool Function(String path)? fileExists,
    bool? isWindows,
  }) : _androidHomeOverride = androidHomeOverride,
       _environment = environment,
       _fileExists = fileExists,
       _isWindows = isWindows ?? Platform.isWindows;

  static const Duration _deviceListTimeout = Duration(seconds: 15);
  static final RegExp _physicalDeviceIdPattern = RegExp(r'^[A-Za-z0-9._:-]+$');

  final CommandExec _exec;
  final String? _androidHomeOverride;
  final Map<String, String>? _environment;
  final bool Function(String path)? _fileExists;
  final bool _isWindows;

  /// SDK binaries are `adb.exe` / `emulator.exe` on Windows.
  String get _exe => _isWindows ? '.exe' : '';

  Map<String, String> get _env => _environment ?? Platform.environment;

  bool _pathExists(String path) =>
      _fileExists?.call(path) ?? File(path).existsSync();

  bool get _hasAdb => adbPath == 'adb' || _pathExists(adbPath);

  bool get _hasSdkEmulator => _pathExists(emulatorPath);

  /// Resolved Android SDK root.
  String getAndroidHome() {
    final override = _androidHomeOverride;
    if (override != null && override.isNotEmpty) return override;

    final env = _env['ANDROID_HOME'] ?? _env['ANDROID_SDK_ROOT'];
    if (env != null && env.isNotEmpty) return env;

    if (_isWindows) return '${_env['LOCALAPPDATA'] ?? ''}/Android/Sdk';

    final home = _env['HOME'] ?? '';
    if (Platform.isLinux) return '$home/Android/Sdk';
    return '$home/Library/Android/sdk';
  }

  /// Path to `adb` (SDK `platform-tools` or `PATH`).
  String get adbPath {
    final sdkAdbPath = '${getAndroidHome()}/platform-tools/adb$_exe';
    if (_pathExists(sdkAdbPath)) return sdkAdbPath;

    return 'adb';
  }

  /// Path to the SDK `emulator` binary.
  String get emulatorPath => '${getAndroidHome()}/emulator/emulator$_exe';

  @override
  Future<bool> isAvailable() async {
    if (!_hasAdb || !_hasSdkEmulator) return false;
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
    if (!_hasSdkEmulator) return [];

    try {
      final result = await _exec.run(
        emulatorPath,
        arguments: ['-list-avds'],
        timeout: _deviceListTimeout,
      );
      if (!result.success) return [];

      final avdNames = result.stdout
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      final runningMap = await _getRunningAvdMap();

      return avdNames.map((name) {
        return Device(
          id: runningMap[name] ?? name,
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
    if (!_hasAdb) return {};

    try {
      final result = await _exec.run(
        adbPath,
        arguments: ['devices'],
        timeout: _deviceListTimeout,
      );
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
              timeout: _deviceListTimeout,
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

  /// Runs `adb connect [host]`.
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

  /// Runs `adb disconnect [host]`.
  Future<bool> disconnectDevice(String host) async {
    try {
      final result = await _exec.run(adbPath, arguments: ['disconnect', host]);
      return result.success;
    } catch (_) {
      return false;
    }
  }

  /// Enables `adb tcpip` on [serial].
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

  /// Reads the device LAN IP via `ip route` / `ifconfig`.
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

  /// Wireless debugging info when the device SDK is 30+.
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

  /// Runs `adb pair [host] [pairingCode]`.
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
      final result = await _exec.run(
        adbPath,
        arguments: ['devices', '-l'],
        timeout: _deviceListTimeout,
      );
      if (!result.success) return [];

      final stdout = result.stdout;

      final rawDevices = stdout
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .where((l) => l != 'List of devices attached')
          .where((l) => !l.startsWith('*'))
          .where((l) => !l.startsWith('daemon'))
          .where((l) => !l.startsWith('adb-'))
          .where((l) => !l.startsWith('emulator-'))
          .where((l) {
            final parts = l.split(RegExp(r'\s+'));
            return parts.length >= 2 &&
                !(parts.length >= 3 &&
                    parts[1] == 'no' &&
                    parts[2].startsWith('permissions')) &&
                _physicalDeviceIdPattern.hasMatch(parts.first);
          });

      return rawDevices
          .map((line) {
            final parts = line.split(RegExp(r'\s+'));
            final id = parts.isNotEmpty ? parts.first : '';
            final adbState = parts.length > 1 ? parts[1] : '';

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
              state: switch (adbState) {
                'device' => DeviceState.booted,
                'unauthorized' ||
                'offline' ||
                'recovery' ||
                'sideload' => DeviceState.booting,
                _ => DeviceState.shutdown,
              },
            );
          })
          .where((d) => d.id.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<bool> shutdownSimulator({required String deviceId}) async {
    try {
      final result = await _exec.run(
        adbPath,
        arguments: ['-s', deviceId, 'emu', 'kill'],
      );
      return result.success;
    } catch (e) {
      return false;
    }
  }
}
