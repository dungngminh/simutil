import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:simutil_core/simutil_core.dart';

import '../devices/devices_cubit.dart';
import '../devices/devices_state.dart';
import '../stream/streams_cubit.dart';

/// Device sections with launch actions.
class DeviceSidebar extends StatelessWidget {
  const DeviceSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSignalBuilder<DevicesCubit, DevicesState>(
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SidebarHeader(loading: state.loading),
          Expanded(
            child: ListView(
              children: [
                _DeviceSection('Android emulators', state.androidEmulators),
                _DeviceSection('Android devices', state.androidDevices),
                _DeviceSection('iOS simulators', state.iosSimulators),
                _DeviceSection('iOS devices', state.iosDevices),
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

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Text('Devices', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          if (loading)
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<DevicesCubit>().refresh(),
          ),
        ],
      ),
    );
  }
}

class _DeviceSection extends StatelessWidget {
  const _DeviceSection(this.title, this.devices);

  final String title;
  final List<Device> devices;

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
        for (final device in devices) DeviceTile(device: device),
      ],
    );
  }
}

/// One device row: name, state, launch button.
class DeviceTile extends StatelessWidget {
  const DeviceTile({super.key, required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final booted = device.state == DeviceState.booted;
    return ListTile(
      dense: true,
      leading: Icon(
        device.os == DeviceOs.android ? Icons.android : Icons.phone_iphone,
        color: booted ? Colors.green : null,
      ),
      title: Text(device.name, overflow: TextOverflow.ellipsis),
      subtitle: Text(device.state.label),
      trailing: switch (device) {
        _ when StreamsCubit.canStream(device) => IconButton(
          tooltip: 'Stream',
          icon: const Icon(Icons.cast),
          onPressed: () => context.read<StreamsCubit>().open(device),
        ),
        _
            when !device.type.isPhysical &&
                device.state == DeviceState.shutdown =>
          IconButton(
            tooltip: 'Launch',
            icon: const Icon(Icons.play_arrow),
            onPressed: () => context.read<DevicesCubit>().launch(device),
          ),
        _ => null,
      },
    );
  }
}
