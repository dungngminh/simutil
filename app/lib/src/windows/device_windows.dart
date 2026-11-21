import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:simutil_core/simutil_core.dart';

/// Devices streaming in their own window. Each window runs its own Flutter
/// engine, so it opens its own session: the main window closes its tile
/// first, and opening a device that has a window shows that window.
class DeviceWindows {
  /// Method a device window answers by stopping its stream.
  static const closeMethod = 'device_window_close';

  /// Method the main window answers by streaming the device (its window
  /// arguments) in the grid again.
  static const backMethod = 'device_window_back';

  /// Method the main window answers by running a [DeviceWindowAction].
  static const actionMethod = 'device_window_action';

  /// True in a device window's engine. Actions that end the device's stream
  /// (restart, shut down…) must run in the main window: a device window
  /// closes, engine and all, once its stream is gone.
  bool inWindow = false;

  /// Set in a device window: stops its stream, hands the device back to
  /// the main window's grid and closes the window.
  Future<void> Function()? backToMain;

  final _moves = StreamController<DeviceMove>.broadcast();

  /// Devices moved into their own window or back to the grid, for toasts.
  Stream<DeviceMove> get moves => _moves.stream;

  /// The window arguments for [device].
  static String argumentsFor(Device device) => jsonEncode(device.toJson());

  /// The device a window was opened for; null for the main window.
  static Device? deviceOf(String arguments) {
    if (arguments.isEmpty) return null;
    try {
      return Device.fromJson(jsonDecode(arguments) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<WindowController?> _find(String deviceId) async {
    for (final window in await WindowController.getAll()) {
      if (deviceOf(window.arguments)?.id == deviceId) return window;
    }
    return null;
  }

  /// Whether any device window is open.
  Future<bool> hasAny() async => (await WindowController.getAll()).any(
    (window) => deviceOf(window.arguments) != null,
  );

  /// Brings [device]'s window to the front; false when it has none.
  Future<bool> focus(Device device) async {
    final window = await _find(device.id);
    if (window == null) return false;
    await window.show();
    return true;
  }

  /// Opens [device] in its own window, or shows the one it has. The window
  /// shows itself once it is sized.
  Future<void> open(Device device) async {
    if (await focus(device)) return;
    await WindowController.create(
      WindowConfiguration(arguments: argumentsFor(device)),
    );
    _moves.add((device: device, back: false));
  }

  /// In the main window: streams a device sent back by its window in the
  /// grid (the window stopped its session first, and is still closing, so
  /// [StreamsCubit.open] must not look for it), and runs actions a device
  /// window hands over with [onAction] (with the window's settings for the
  /// device, which it cannot save itself).
  Future<void> listen(
    Future<void> Function(Device device) openInGrid, {
    Future<void> Function(
      Device device,
      DeviceWindowAction action,
      Object? settings,
    )?
    onAction,
  }) async {
    final main = await WindowController.fromCurrentEngine();
    await main.setWindowMethodHandler((call) async {
      switch (call.method) {
        case backMethod:
          if (deviceOf(call.arguments as String? ?? '') case final device?) {
            _moves.add((device: device, back: true));
            unawaited(openInGrid(device));
          }
        case actionMethod:
          final args = jsonDecode(call.arguments as String? ?? '{}');
          if (args case {
            'device': final String device,
            'action': final String action,
          }) {
            final target = deviceOf(device);
            final kind = DeviceWindowAction.values.asNameMap()[action];
            if (target == null || kind == null || onAction == null) return;
            // The window closes while this runs; do not keep it waiting.
            unawaited(onAction(target, kind, args['settings']));
          }
      }
    });
  }

  /// In a device window: has the main window run [action] on [device],
  /// with this window's [settings] for it.
  static Future<void> sendAction(
    Device device,
    DeviceWindowAction action, {
    Object? settings,
  }) async {
    for (final window in await WindowController.getAll()) {
      if (window.arguments.isEmpty) {
        await window.invokeMethod<void>(
          actionMethod,
          jsonEncode({
            'device': argumentsFor(device),
            'action': action.name,
            'settings': settings,
          }),
        );
      }
    }
  }

  /// In a device window: asks the main window to stream [device] again.
  static Future<void> sendBack(Device device) async {
    for (final window in await WindowController.getAll()) {
      if (window.arguments.isEmpty) {
        await window.invokeMethod<void>(backMethod, argumentsFor(device));
      }
    }
  }

  /// Has every device window stop its stream; for quitting.
  Future<void> closeAll() async {
    final List<WindowController> windows;
    try {
      windows = await WindowController.getAll();
    } catch (_) {
      return; // quitting still releases the main window's services
    }
    for (final window in windows) {
      if (deviceOf(window.arguments) == null) continue;
      try {
        await window
            .invokeMethod<void>(closeMethod)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // A window that does not answer must not block quitting.
      }
    }
  }
}

/// What a device window hands to the main window (see
/// [DeviceWindows.inWindow]).
enum DeviceWindowAction { stop, restart, slim, unslim, disconnect }

/// [device] moved into its own window, or [back] to the main window's grid.
typedef DeviceMove = ({Device device, bool back});
