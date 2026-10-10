import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:simutil_core/simutil_core.dart';

import '../../devices/devices_cubit.dart';
import '../../devices/devices_state.dart';
import '../../settings/view_settings_cubit.dart';
import '../../stream/streams_cubit.dart';

/// What a device row can do; each design maps it to its own icon.
enum DeviceActionKind { start, stop, stream, slimOn, slimOff }

typedef DeviceAction = ({
  DeviceActionKind kind,
  String label,
  VoidCallback onPressed,
});

/// Actions for [device] in its current state.
List<DeviceAction> deviceActions(
  BuildContext context,
  Device device,
  DevicesState state,
) {
  if (state.busy.contains(device.id)) return const [];
  final devices = context.read<DevicesCubit>();
  final streams = context.read<StreamsCubit>();
  final headless = context.read<ViewSettingsCubit>().stateValue.headless;
  final isSim = !device.type.isPhysical;
  final booted = device.state == DeviceState.booted;
  final slim = state.slimmed.contains(device.id);
  return [
    if (StreamsCubit.canStream(device))
      (
        kind: DeviceActionKind.stream,
        label: 'Stream',
        onPressed: () => streams.open(device),
      ),
    if (isSim && device.state == DeviceState.shutdown)
      (
        kind: DeviceActionKind.start,
        label: headless ? 'Start and stream' : 'Start',
        onPressed: () {
          if (headless) streams.openWhenBooted(device);
          devices.launch(device, headless: headless);
        },
      ),
    if (isSim && booted)
      (
        kind: DeviceActionKind.stop,
        label: 'Shut down',
        onPressed: () {
          streams.closeStream(device.id);
          devices.shutdown(device);
        },
      ),
    if (isSim && device.os == DeviceOs.ios)
      (
        kind: slim ? DeviceActionKind.slimOff : DeviceActionKind.slimOn,
        label: slim
            ? 'Restore all services (reboots)'
            : 'Slim: disable background services (reboots)',
        onPressed: () => devices.toggleSlim(device),
      ),
  ];
}
