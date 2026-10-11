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
  Future<void> launch(Device device, String appId) async {
    final result = await _exec.run(
      'xcrun',
      arguments: device.type.isPhysical
          ? [
              'devicectl',
              'device',
              'process',
              'launch',
              '--device',
              device.id,
              appId,
            ]
          : ['simctl', 'launch', device.id, appId],
      timeout: const Duration(seconds: 30),
    );
    if (!result.success) {
      throw StateError(
        'Could not launch $appId on ${device.name}: ${result.stderr}'.trim(),
      );
    }
  }

  @override
  Future<void> typeText(Device device, String text) =>
      throw UnsupportedError('Typing on iOS needs a native input bridge');

  @override
  Future<List<UiElement>> elements(Device device) => throw UnsupportedError(
    'iOS accessibility needs a native accessibility bridge',
  );
}
