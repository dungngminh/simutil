import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_app/src/devices/devices_state.dart';
import 'package:simutil_app/src/settings/device_settings_cubit.dart';
import 'package:simutil_app/src/settings/view_settings_cubit.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_core/simutil_core.dart';

/// What a device row can do; each design maps it to its own icon.
enum DeviceActionKind { start, stop, stream }

typedef DeviceAction = ({
  DeviceActionKind kind,
  String label,
  Future<void> Function() onPressed,
});

/// Start / stop / restart for one device, using its per-device settings and
/// keeping its stream in step.
class DeviceCommands {
  DeviceCommands(BuildContext context, this.device)
    : _devices = context.read<DevicesCubit>(),
      _streams = context.read<StreamsCubit>(),
      settings = context.read<DeviceSettingsCubit>().of(device),
      _globalHeadless = context.read<ViewSettingsCubit>().stateValue.headless;

  final Device device;
  final DeviceSettings settings;
  final DevicesCubit _devices;
  final StreamsCubit _streams;
  final bool _globalHeadless;

  bool get headless => settings.headless ?? _globalHeadless;

  Future<void> start() async {
    if (headless) _streams.openWhenBooted(device);
    await _devices.launch(
      device,
      headless: headless,
      coldBoot: settings.coldBoot,
      noAudio: settings.noAudio,
    );
  }

  Future<void> stop() async {
    await _streams.closeStream(device.id);
    await _devices.shutdown(device);
  }

  /// Reboots the device and reopens its stream if it had one (or runs
  /// headless).
  Future<void> restart() async {
    final reopen = headless || _streams.stateValue.isOpen(device.id);
    await _streams.closeStream(device.id);
    await _devices.restart(
      device,
      headless: headless,
      coldBoot: settings.coldBoot,
      noAudio: settings.noAudio,
    );
    // After the restart so the old, still-booted device is not reopened.
    if (reopen) _streams.openWhenBooted(device);
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
