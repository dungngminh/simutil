import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_app/src/stream/ios/ios_sim_session.dart';
import 'package:simutil_apple/simutil_apple.dart';
import 'package:simutil_core/simutil_core.dart';

/// [DeviceAutomation] for every platform the app streams: Android through
/// adb, iOS launches through xcrun, and iOS simulator typing and
/// accessibility through the native stream plugin of the device's open
/// [IosSimSession] (found with [iosSession]).
class AppAutomation implements DeviceAutomation {
  AppAutomation({
    required this.android,
    required this.ios,
    required this.iosSession,
  });

  final DeviceAutomation android;
  final DeviceAutomation ios;
  final IosSimSession? Function(String deviceId) iosSession;

  DeviceAutomation _of(Device device) =>
      device.os == DeviceOs.android ? android : ios;

  @override
  Future<void> launch(Device device, String appId) =>
      _of(device).launch(device, appId);

  @override
  Future<void> typeText(Device device, String text) =>
      iosSession(device.id)?.typeText(text) ??
      _of(device).typeText(device, text);

  @override
  Future<List<UiElement>> elements(Device device) =>
      iosSession(device.id)?.accessibilityElements() ??
      _of(device).elements(device);
}

/// The production [AppAutomation].
AppAutomation appAutomation({
  required CommandExec exec,
  required String Function() adbPath,
  required DeviceSession? Function(String deviceId) session,
}) => AppAutomation(
  android: AndroidAutomation(exec, adbPath: adbPath),
  ios: IosAutomation(exec),
  iosSession: (id) => switch (session(id)) {
    final IosSimSession s => s,
    _ => null,
  },
);
