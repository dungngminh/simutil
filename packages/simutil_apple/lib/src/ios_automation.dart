import 'dart:io';

import 'package:simutil_core/simutil_core.dart';

/// [DeviceAutomation] for iOS simulators (`simctl`) and devices
/// (`devicectl`). Only [install] and [launch] work from Dart: typing and the
/// accessibility tree need private simulator frameworks in native code
/// (the SimUtil desktop app's stream plugin), so they throw here.
abstract interface class IosAutomation implements DeviceAutomation {
  /// Runs xcrun through [exec].
  factory IosAutomation(CommandExec exec) = _IosAutomation;
}

class _IosAutomation implements IosAutomation {
  _IosAutomation(this._exec);

  final CommandExec _exec;

  @override
  Future<void> install(Device device, String path) async {
    Directory? unpacked;
    try {
      var app = path;
      if (path.toLowerCase().endsWith('.ipa')) {
        unpacked = await Directory.systemTemp.createTemp('simutil_ipa');
        app = await _unpackIpa(path, unpacked);
      }
      if (!device.type.isPhysical && await _deviceOnly(app)) {
        throw StateError(
          '${app.split('/').last} is built for iPhone and iPad devices, not '
          'the simulator. Build it for the simulator or install it on a device.',
        );
      }
      if (device.type.isPhysical && await _storeSigned(app)) {
        throw StateError(
          '${app.split('/').last} is signed for the App Store, which iOS only '
          'installs from the App Store or TestFlight. Use a development or '
          'ad hoc build.',
        );
      }
      final result = await _exec.run(
        'xcrun',
        arguments: device.type.isPhysical
            ? [
                'devicectl',
                'device',
                'install',
                'app',
                '--device',
                device.id,
                app,
              ]
            : ['simctl', 'install', device.id, app],
        timeout: const Duration(minutes: 5),
      );
      if (!result.success) {
        throw StateError(
          'Could not install on ${device.name}: ${result.stderr}'.trim(),
        );
      }
    } finally {
      await unpacked?.delete(recursive: true);
    }
  }

  /// Whether the bundle at [app] only runs on devices: simctl stages it and
  /// then fails with a long installd error.
  Future<bool> _deviceOnly(String app) async {
    final result = await _exec.run(
      'plutil',
      arguments: [
        '-extract',
        'CFBundleSupportedPlatforms',
        'json',
        '-o',
        '-',
        '$app/Info.plist',
      ],
      timeout: const Duration(seconds: 10),
    );
    final platforms = result.stdout;
    return result.success &&
        platforms.contains('iPhoneOS') &&
        !platforms.contains('iPhoneSimulator');
  }

  /// Whether the bundle at [app] carries an App Store profile (no device
  /// list, not enterprise): devicectl only fails with CoreDevice error 3002.
  Future<bool> _storeSigned(String app) async {
    final result = await _exec.run(
      'security',
      arguments: ['cms', '-D', '-i', '$app/embedded.mobileprovision'],
      timeout: const Duration(seconds: 10),
    );
    final profile = result.stdout;
    return result.success &&
        profile.contains('<plist') &&
        !profile.contains('ProvisionedDevices') &&
        !profile.contains('ProvisionsAllDevices');
  }

  /// Extracts [ipa] into [dir] and returns its `Payload/*.app`.
  Future<String> _unpackIpa(String ipa, Directory dir) async {
    final result = await _exec.run(
      'unzip',
      arguments: ['-q', ipa, '-d', dir.path],
      timeout: const Duration(minutes: 2),
    );
    if (!result.success) {
      throw StateError('Could not unpack $ipa: ${result.stderr}'.trim());
    }
    final payload = Directory('${dir.path}/Payload');
    final app = payload.existsSync()
        ? payload.listSync().where((e) => e.path.endsWith('.app')).firstOrNull
        : null;
    if (app == null) throw StateError('No app inside $ipa');
    return app.path;
  }

  @override
  Future<void> launch(
    Device device,
    String appId, {
    bool clearState = false,
  }) async {
    if (clearState) await _clearState(device, appId);
    final result = await _exec.run(
      'xcrun',
      arguments: device.type.isPhysical
          ? [
              'devicectl',
              'device',
              'process',
              'launch',
              '--terminate-existing',
              '--device',
              device.id,
              appId,
            ]
          : [
              'simctl',
              'launch',
              '--terminate-running-process',
              device.id,
              appId,
            ],
      timeout: const Duration(seconds: 30),
    );
    if (!result.success) {
      throw StateError(
        'Could not launch $appId on ${device.name}: ${result.stderr}'.trim(),
      );
    }
  }

  /// Stops [appId] and empties its data container (Documents, Library,
  /// tmp). ponytail: app group containers and keychain items stay; erase the
  /// simulator when those matter.
  Future<void> _clearState(Device device, String appId) async {
    if (device.type.isPhysical) {
      throw UnsupportedError('Clearing app state needs a simulator');
    }
    await _exec.run(
      'xcrun',
      arguments: ['simctl', 'terminate', device.id, appId],
      timeout: const Duration(seconds: 15),
    );
    final container = await _exec.run(
      'xcrun',
      arguments: ['simctl', 'get_app_container', device.id, appId, 'data'],
      timeout: const Duration(seconds: 15),
    );
    final path = container.stdout.trim();
    if (!container.success || path.isEmpty) {
      throw StateError(
        'No data container for $appId on ${device.name}: '
                '${container.stderr}'
            .trim(),
      );
    }
    try {
      for (final entry in Directory(path).listSync()) {
        entry.deleteSync(recursive: true);
      }
      // The app expects these to exist on first launch.
      for (final dir in ['Documents', 'Library', 'tmp']) {
        Directory('$path/$dir').createSync(recursive: true);
      }
    } on FileSystemException catch (e) {
      throw StateError('Could not clear $appId on ${device.name}: $e');
    }
  }

  @override
  Future<void> typeText(Device device, String text) =>
      throw UnsupportedError('Typing on iOS needs a native input bridge');

  @override
  Future<bool> tapElement(Device device, UiElement element) async => false;

  @override
  Future<List<UiElement>> elements(Device device) => throw UnsupportedError(
    'iOS accessibility needs a native accessibility bridge',
  );
}
