import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:simutil_core/simutil_core.dart';

import '../../devices/device_form_factor.dart';
import '../../devices/devices_cubit.dart';
import '../../devices/devices_state.dart';
import '../shared/device_actions.dart';
import '../shared/device_context_menu.dart';

/// Device sections with Launch / Stream actions.
class MaterialDeviceList extends StatelessWidget {
  const MaterialDeviceList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSignalBuilder<DevicesCubit, DevicesState>(
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView(
              children: [
                _DeviceSection(
                  'Android emulators',
                  state.androidEmulators,
                  state,
                ),
                _DeviceSection('Android devices', state.androidDevices, state),
                _DeviceSection('iOS simulators', state.iosSimulators, state),
                _DeviceSection('iOS devices', state.iosDevices, state),
              ],
            ),
          ),
          if (state.message case final message?)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _DeviceSection extends StatelessWidget {
  const _DeviceSection(this.title, this.devices, this.state);

  final String title;
  final List<Device> devices;
  final DevicesState state;

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(title, style: Theme.of(context).textTheme.labelLarge),
        ),
        for (final device in devices) _DeviceTile(device: device, state: state),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.state});

  final Device device;
  final DevicesState state;

  static IconData _actionIcon(DeviceActionKind kind) => switch (kind) {
    DeviceActionKind.start => Icons.play_arrow,
    DeviceActionKind.stop => Icons.power_settings_new,
    DeviceActionKind.stream => Icons.cast,
    DeviceActionKind.slimOn => Icons.eco_outlined,
    DeviceActionKind.slimOff => Icons.eco,
  };

  @override
  Widget build(BuildContext context) {
    final booted = device.state == DeviceState.booted;
    final busy = state.busy.contains(device.id);
    final slim = state.slimmed.contains(device.id);
    return GestureDetector(
      onSecondaryTap: () => showDeviceContextMenu(context, device),
      child: ListTile(
        dense: true,
        leading: Icon(switch (DeviceFormFactor.of(device)) {
          DeviceFormFactor.phone =>
            device.os == DeviceOs.android
                ? Icons.smartphone
                : Icons.phone_iphone,
          DeviceFormFactor.tablet =>
            device.os == DeviceOs.android
                ? Icons.tablet_android
                : Icons.tablet_mac,
          DeviceFormFactor.tv => Icons.tv,
          DeviceFormFactor.watch => Icons.watch,
        }, color: booted ? Colors.green : null),
        title: Text(device.name, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          slim ? '${device.state.label} · slim' : device.state.label,
        ),
        trailing: busy
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final action in deviceActions(context, device, state))
                    IconButton(
                      tooltip: action.label,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(_actionIcon(action.kind), size: 18),
                      onPressed: action.onPressed,
                    ),
                ],
              ),
      ),
    );
  }
}
