import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_app/src/di.dart';
import 'package:simutil_app/src/devices/devices_state.dart';
import 'package:simutil_app/src/settings/device_settings_cubit.dart';
import 'package:simutil_app/src/settings/view_settings_cubit.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_app/src/windows/device_windows.dart';
import 'package:simutil_core/simutil_core.dart';

/// What a device row can do; each design maps it to its own icon.
enum DeviceActionKind { start, stop, stream }

typedef DeviceAction = ({
  DeviceActionKind kind,
  String label,
  Future<void> Function() onPressed,
});

/// Start / stop / restart for one device, using its per-device settings and
/// keeping its stream in step. In a device window, stop and restart run in
/// the main window (see [DeviceWindows.inWindow]).
class DeviceCommands {
  DeviceCommands(BuildContext context, this.device)
    : _devices = context.read<DevicesCubit>(),
      _streams = context.read<StreamsCubit>(),
      settings = context.read<DeviceSettingsCubit>().of(device),
      _globalHeadless = context.read<ViewSettingsCubit>().stateValue.headless,
      _inWindow =
          getIt.isRegistered<DeviceWindows>() &&
          getIt<DeviceWindows>().inWindow,
      _reopenInWindow = null;

  /// For the main window running an action a device window handed over:
  /// [reopenInWindow] brings the device back in its own window once booted.
  DeviceCommands.forWindow({
    required this.device,
    required this.settings,
    required DevicesCubit devices,
    required StreamsCubit streams,
    required bool globalHeadless,
    required void Function(Device device) reopenInWindow,
  }) : _devices = devices,
       _streams = streams,
       _globalHeadless = globalHeadless,
       _inWindow = false,
       _reopenInWindow = reopenInWindow;

  final Device device;
  final DeviceSettings settings;
  final DevicesCubit _devices;
  final StreamsCubit _streams;
  final bool _globalHeadless;
  final bool _inWindow;
  final void Function(Device device)? _reopenInWindow;

  bool get headless => settings.headless ?? _globalHeadless;

  /// Boots the device; Android emulators can boot cold (no snapshot) or
  /// muted for this launch only.
  Future<void> start({bool coldBoot = false, bool noAudio = false}) async {
    if (headless) _streams.openWhenBooted(device);
    await _devices.launch(
      device,
      headless: headless,
      coldBoot: coldBoot,
      noAudio: noAudio,
      cameraArgs: _cameraArgs(),
    );
  }

  /// The emulator camera sources picked in the context menu; a missing file
  /// shows an error and boots with the AVD's own cameras.
  List<String> _cameraArgs() {
    if (device.os != DeviceOs.android) return const [];
    try {
      return emulatorCameraArgs(
        back: settings.cameraBack,
        front: settings.cameraFront,
      );
    } on FormatException catch (e) {
      _devices.notify('Camera: ${e.message}', error: true);
      return const [];
    }
  }

  Future<void> stop() async {
    if (_inWindow) {
      return DeviceWindows.sendAction(device, DeviceWindowAction.stop);
    }
    await _streams.closeStream(device.id);
    await _devices.shutdown(device);
  }

  /// Reboots the device and reopens its stream if it had one (or runs
  /// headless).
  Future<void> restart() async {
    if (_inWindow) {
      return DeviceWindows.sendAction(
        device,
        DeviceWindowAction.restart,
        settings: settings.toJson(),
      );
    }
    final reopenInWindow = _reopenInWindow;
    final reopen =
        reopenInWindow != null ||
        headless ||
        _streams.stateValue.isOpen(device.id);
    await _streams.closeStream(device.id);
    await _devices.restart(
      device,
      headless: headless,
      cameraArgs: _cameraArgs(),
    );
    // After the restart so the old, still-booted device is not reopened.
    if (!reopen) return;
    reopenInWindow != null
        ? reopenInWindow(device)
        : _streams.openWhenBooted(device);
  }
}

/// Row actions for [device]: Start when it is off, Stream and Stop when it
/// runs. Everything else lives in the context menu.
List<DeviceAction> deviceActions(
  BuildContext context,
  Device device,
  DevicesState state,
) {
  if (state.busy.contains(device.id)) return const [];
  final commands = DeviceCommands(context, device);
  final streams = context.read<StreamsCubit>();
  final isSim = !device.type.isPhysical;
  return [
    if (isSim && device.state == DeviceState.shutdown)
      (
        kind: DeviceActionKind.start,
        label: commands.headless ? 'Start and stream' : 'Start',
        onPressed: commands.start,
      ),
    if (StreamsCubit.canStream(device))
      (
        kind: DeviceActionKind.stream,
        label: 'Stream',
        onPressed: () => streams.open(device),
      ),
    if (isSim && device.state == DeviceState.booted)
      (
        kind: DeviceActionKind.stop,
        label: 'Shut down',
        onPressed: commands.stop,
      ),
  ];
}
