import 'dart:io';

import 'package:simutil_core/simutil_core.dart';

/// [DeviceAutomation] for iOS simulators (`simctl`) and devices
/// (`devicectl`). Only [launch] works from Dart: typing and the
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
