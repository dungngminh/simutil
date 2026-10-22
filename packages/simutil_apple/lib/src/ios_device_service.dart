import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:simutil_apple/src/apple_device_watch.dart';
import 'package:simutil_apple/src/usbmux.dart' as usbmux;
import 'package:simutil_core/simutil_core.dart';

/// Apple simulators (`simctl`) and physical devices (usbmuxd + lockdownd,
/// falling back to `devicectl`).
///
/// Covers iPhone, iPad, Watch, TV, and other CoreSimulator runtimes.
/// No-ops on non-macOS hosts.
class IOSDeviceService implements DeviceService {
  /// Creates a service that runs `xcrun` via [CommandExec].
  ///
  /// [pathExists] overrides the directory check used to locate the
  /// simulator app, and [listUsbmuxDevices] the usbmuxd device lookup
  /// (both for tests).
  IOSDeviceService(
    this._exec, {
    bool Function(String path)? pathExists,
    Future<List<Device>?> Function()? listUsbmuxDevices,
  }) : _pathExists = pathExists ?? _directoryExists,
       _listUsbmuxDevices = listUsbmuxDevices ?? usbmux.listUsbmuxDevices;

  final CommandExec _exec;
  final bool Function(String path) _pathExists;
  final Future<List<Device>?> Function() _listUsbmuxDevices;

  static bool _directoryExists(String path) => Directory(path).existsSync();

  @override
  Stream<void> watchDevices() =>
      Platform.isMacOS ? watchAppleDevices() : const Stream.empty();

  @override
  Future<bool> isAvailable() async {
    if (!Platform.isMacOS) return false;
    try {
      final result = await _exec.run(
        'xcrun',
        arguments: ['simctl', 'list', '--json'],
        priority: CommandPriority.background,
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
        priority: CommandPriority.background,
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
  /// Parses `xcrun simctl list devices -j` JSON into [Device]s.
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
    bool headless = false,
  }) async {
    await bootSimulator(deviceId);
    if (!headless) await openSimulatorApp(deviceId);
  }

  /// Boots the simulator [udid] via `simctl boot`.
  Future<bool> bootSimulator(String udid) async {
    try {
      final result = await _exec.run(
        'xcrun',
        arguments: ['simctl', 'boot', udid],
        priority: CommandPriority.interactive,
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
    await _exec.run(
      'open',
      arguments: openSimulatorArguments(
        uuid: uuid,
        appPath: await _simulatorAppPath(),
      ),
      priority: CommandPriority.interactive,
    );
  }

  Future<String?> _simulatorAppPath() async => resolveSimulatorAppPath(
    developerPath: await _xcodeDeveloperPath(),
    exists: _pathExists,
  );

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

  /// Whether [appPath] is DeviceHub.app, i.e. the selected Xcode is 27+.
  static bool isDeviceHub(String? appPath) =>
      appPath != null && p.posix.basename(appPath) == 'DeviceHub.app';

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
    if (!isDeviceHub(appPath)) {
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
        priority: CommandPriority.interactive,
      );
      return result.success;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> deleteSimulator({required String deviceId}) async {
    try {
      final result = await _exec.run(
        'xcrun',
        arguments: ['simctl', 'delete', deviceId],
        priority: CommandPriority.interactive,
      );
      return result.success;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> wipeData({required String deviceId}) async {
    try {
      final result = await _exec.run(
        'xcrun',
        arguments: ['simctl', 'erase', deviceId],
        priority: CommandPriority.interactive,
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

  /// Asks usbmuxd and each device's lockdownd first: no process, and no
  /// simulators to filter out. `devicectl` (a second or more) only runs when
  /// usbmuxd does not answer.
  @override
  Future<List<Device>> getPhysicalDevices() async {
    if (!Platform.isMacOS) return [];
    return await _listUsbmuxDevices() ?? await _listDevicectlDevices();
  }

  Future<List<Device>> _listDevicectlDevices() async {
    final tempDirectory = Directory.systemTemp;
    final outputFile = File('${tempDirectory.path}/ios_devices.json');

    try {
      final devicectl = await _exec.run(
        'xcrun',
        arguments: listPhysicalDevicesArguments(
          outputPath: outputFile.path,
          xcode27: isDeviceHub(await _simulatorAppPath()),
        ),
        priority: CommandPriority.background,
      );

      if (!devicectl.success) return [];

      final json =
          jsonDecode(await outputFile.readAsString()) as Map<String, dynamic>;

      return parsePhysicalDevices(json);
    } catch (e, st) {
      log('IOSDeviceService._listDevicectlDevices error: $e\n$st');
      return [];
    } finally {
      if (outputFile.existsSync()) {
        outputFile.deleteSync();
      }
    }
  }

  /// `xcrun devicectl list devices` arguments writing JSON to [outputPath].
  ///
  /// Xcode 27+ lists booted simulators too, so ask for physical devices only.
  /// Older Xcodes list hardware only and match nothing with that filter.
  static List<String> listPhysicalDevicesArguments({
    required String outputPath,
    required bool xcode27,
  }) => [
    'devicectl',
    'list',
    'devices',
    if (xcode27) ...['--filter', "Reality = 'physical'"],
    '-j',
    outputPath,
  ];

  /// Parses `xcrun devicectl list devices -j` JSON into connected hardware,
  /// skipping simulators. Pure function (no I/O) so it is unit-testable on
  /// any platform.
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
      final hardware = map['hardwareProperties'] as Map<String, dynamic>?;
      // The hardware UDID, as usbmuxd reports it; `identifier` is a
      // CoreDevice UUID.
      final identifier =
          hardware?['udid'] as String? ?? map['identifier'] as String? ?? '';
      final name = deviceProps['name'] as String? ?? '';
      final osVersion = deviceProps['osVersionNumber'] as String? ?? '';
      if (_deviceReality(map) == 'simulated') continue;
      // A device on USB or Wi-Fi has a transport; its tunnel stays
      // disconnected until Xcode or devicectl uses it.
      final tunnelState = connectionProps['tunnelState'] as String?;
      final isConnected =
          connectionProps['transportType'] != null ||
          !['unavailable', 'disconnected'].contains(tunnelState);
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
