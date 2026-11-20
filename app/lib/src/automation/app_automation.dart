import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_app/src/stream/ios/ios_sim_session.dart';
import 'package:simutil_apple/simutil_apple.dart';
import 'package:simutil_core/simutil_core.dart';

/// [DeviceAutomation] for every platform the app streams: Android through
/// adb, iOS installs and launches through xcrun, and iOS simulator typing and
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
  Future<void> install(Device device, String path) =>
      _of(device).install(device, path);

  @override
  Future<void> launch(Device device, String appId, {bool clearState = false}) =>
      _of(device).launch(device, appId, clearState: clearState);

  @override
  Future<void> typeText(Device device, String text) =>
      iosSession(device.id)?.typeText(text) ??
      _of(device).typeText(device, text);

  @override
  Future<bool> tapElement(Device device, UiElement element) async {
    final session = iosSession(device.id);
    if (session == null) return _of(device).tapElement(device, element);
    final settled = await _settled(session, element, _snapshots[device.id]);
    return session.pressElement(settled ?? element);
  }

  /// The last iOS accessibility listing per device, the one a tap's element
  /// was most likely found in; tells which of several look-alikes it is.
  final _snapshots = <String, List<UiElement>>{};

  /// [element] once its frame holds still across two snapshots (an alert or
  /// sheet still animating in ignores presses), with a fresh handle; null
  /// when it is gone. Snapshots are cheap on iOS (~0.1 s), so this waits
  /// at most [settleTimeout].
  /// ponytail: Android skips this; each dump there costs ~2.5 s.
  static const settleTimeout = Duration(seconds: 2);

  Future<UiElement?> _settled(
    IosSimSession session,
    UiElement element,
    List<UiElement>? foundIn,
  ) async {
    bool same(UiElement a, UiElement b) =>
        a.label == b.label &&
        a.id == b.id &&
        (a.left - b.left).abs() < 0.002 &&
        (a.top - b.top).abs() < 0.002 &&
        (a.right - b.right).abs() < 0.002 &&
        (a.bottom - b.bottom).abs() < 0.002;
    // Labels repeat (two "Delete" buttons, or none at all on an element
    // found by its value). Look-alikes keep their order in the tree while a
    // sheet moves them together, so follow the element by its rank among
    // them; only when their number changes, by where it last was.
    bool twin(UiElement a, UiElement b) =>
        a.label == b.label && a.id == b.id && a.role == b.role;
    final twins = [...?foundIn?.where((e) => twin(e, element))];
    final rank = twins.indexWhere(
      (e) => e.handle == element.handle && same(e, element),
    );
    double distance(UiElement a, UiElement b) =>
        (a.centerX - b.centerX).abs() + (a.centerY - b.centerY).abs();
    UiElement? match(List<UiElement> all, UiElement like) {
      final now = [...all.where((e) => twin(e, like))];
      if (rank >= 0 && now.length == twins.length) return now[rank];
      UiElement? best;
      for (final e in now) {
        if (best == null || distance(e, like) < distance(best, like)) best = e;
      }
      return best;
    }

    final clock = Stopwatch()..start();
    var last = element;
    while (clock.elapsed < settleTimeout) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final now = match(await session.accessibilityElements(), last);
      if (now == null) return null;
      if (same(now, last)) return now;
      last = now;
    }
    return last;
  }

  @override
  Future<List<UiElement>> elements(Device device) async {
    final session = iosSession(device.id);
    if (session == null) return _of(device).elements(device);
    return _snapshots[device.id] = await session.accessibilityElements();
  }
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
