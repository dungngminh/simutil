import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:macos_ui/macos_ui.dart';
import 'package:simutil_core/simutil_core.dart';

import '../../devices/device_form_factor.dart';
import '../../devices/devices_cubit.dart';
import '../../devices/devices_state.dart';
import '../shared/device_actions.dart';
import '../shared/device_context_menu.dart';

/// Sidebar sections with Launch / Stream actions.
class MacosDeviceList extends StatelessWidget {
  const MacosDeviceList({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return BlocSignalBuilder<DevicesCubit, DevicesState>(
      builder: (context, state) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        children: [
          if (state.loading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: ProgressCircle(radius: 8)),
            ),
          _Section('Android Emulators', state.androidEmulators, state),
          _Section('Android Devices', state.androidDevices, state),
          _Section('iOS Simulators', state.iosSimulators, state),
          _Section('iOS Devices', state.iosDevices, state),
          if (state.message case final message?)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                message,
                style: MacosTheme.of(context).typography.caption1,
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.devices, this.state);

  final String title;
  final List<Device> devices;
  final DevicesState state;

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) return const SizedBox.shrink();
    final typography = MacosTheme.of(context).typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
          child: Text(
            title,
            style: typography.subheadline.copyWith(
              color: MacosColors.systemGrayColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final device in devices) _DeviceRow(device: device, state: state),
      ],
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device, required this.state});

  final Device device;
  final DevicesState state;

  static IconData _actionIcon(DeviceActionKind kind) => switch (kind) {
    DeviceActionKind.start => CupertinoIcons.play_fill,
    DeviceActionKind.stop => CupertinoIcons.power,
    DeviceActionKind.stream => CupertinoIcons.play_rectangle,
    DeviceActionKind.slimOn => CupertinoIcons.leaf_arrow_circlepath,
    DeviceActionKind.slimOff => CupertinoIcons.arrow_counterclockwise,
  };

  @override
  Widget build(BuildContext context) {
    final booted = device.state == DeviceState.booted;
    final busy = state.busy.contains(device.id);
    final slim = state.slimmed.contains(device.id);
    return GestureDetector(
      onSecondaryTap: () => showDeviceContextMenu(context, device),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: MacosListTile(
                leading: MacosIcon(switch (DeviceFormFactor.of(device)) {
                  DeviceFormFactor.phone =>
                    CupertinoIcons.device_phone_portrait,
                  DeviceFormFactor.tablet => Icons.tablet_mac,
                  DeviceFormFactor.tv => CupertinoIcons.tv,
                  DeviceFormFactor.watch => Icons.watch_outlined,
                }, color: booted ? MacosColors.systemGreenColor : null),
                title: Text(device.name, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  slim ? '${device.state.label} · slim' : device.state.label,
                ),
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(6),
                child: ProgressCircle(radius: 7),
              )
            else
              for (final action in deviceActions(context, device, state))
                MacosTooltip(
                  message: action.label,
                  child: MacosIconButton(
                    icon: MacosIcon(_actionIcon(action.kind), size: 15),
                    semanticLabel: action.label,
                    onPressed: action.onPressed,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
