import 'dart:io';

import '../models/device.dart';
import '../models/device_state.dart';
import '../models/device_type.dart';
import '../models/launch_options.dart';
import 'command_exec.dart';
import 'device_service.dart';

/// Service for interacting with Android emulators via `adb` and `emulator` CLI.
///
/// Resolves tool paths through `$ANDROID_HOME` (or the default macOS SDK path)
/// following the same strategy as MiniSim.
class AdbService implements DeviceService {
  final CommandExec _exec;

  AdbService(this._exec);

  // ── Path helpers ──────────────────────────────────────────────

  /// Resolve `ANDROID_HOME`, falling back to `~/Library/Android/sdk` on macOS.
  String getAndroidHome() {
    final env =
        Platform.environment['ANDROID_HOME'] ??
        Platform.environment['ANDROID_SDK_ROOT'];
    if (env != null && env.isNotEmpty) return env;

    // Default macOS path (same as MiniSim).
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
  Future<List<Device>> listDevices() => listEmulators();

  /// List all Android Virtual Devices (AVDs) and their running state.
  Future<List<Device>> listEmulators() async {
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
          type: DeviceType.android,
          platform: 'Android',
          state: runningMap.containsKey(name)
              ? DeviceState.booted
              : DeviceState.shutdown,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Query every online `emulator-*` device for its AVD name.
  ///
  /// Returns a `{avdName: serialId}` map so we can accurately match AVD names
  /// (the same approach MiniSim uses in `getAdbId`).
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
      for (final serial in serials) {
        try {
          // `adb -s <serial> emu avd name` returns the AVD name on the first line.
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
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  /// Look up the adb serial (e.g. `emulator-5554`) for a given AVD name.
  Future<String?> getAdbId(String avdName) async {
    final map = await _getRunningAvdMap();
    return map[avdName];
  }

  // ── Launch ────────────────────────────────────────────────────

  @override
  Future<void> launchDevice(String deviceId, LaunchOptions options) =>
      launchEmulator(deviceId, options);

  /// Launch an Android emulator by AVD name with the given options.
  Future<void> launchEmulator(String avdName, LaunchOptions options) async {
    final args = ['@$avdName', ...options.toAndroidArgs()];
    await Process.start(emulatorPath, args, mode: ProcessStartMode.detached);
  }
}