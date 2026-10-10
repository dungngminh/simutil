import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:simutil_core/simutil_core.dart';

import '../../devices/devices_cubit.dart';
import '../../devices/devices_state.dart';
import '../../stream/streams_cubit.dart';

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
          _Section('Android Emulators', state.androidEmulators),
          _Section('Android Devices', state.androidDevices),
          _Section('iOS Simulators', state.iosSimulators),
          _Section('iOS Devices', state.iosDevices),
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
  const _Section(this.title, this.devices);

  final String title;
  final List<Device> devices;

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
        for (final device in devices) _DeviceRow(device: device),
      ],
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final booted = device.state == DeviceState.booted;
    final action = switch (device) {
      _ when StreamsCubit.canStream(device) => (
        CupertinoIcons.play_rectangle,
        'Stream',
        () => context.read<StreamsCubit>().open(device),
      ),
      _ when !device.type.isPhysical && device.state == DeviceState.shutdown =>
        (
          CupertinoIcons.play_fill,
          'Launch',
          () => context.read<DevicesCubit>().launch(device),
        ),
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: MacosListTile(
              leading: MacosIcon(
                CupertinoIcons.device_phone_portrait,
                color: booted ? MacosColors.systemGreenColor : null,
              ),
              title: Text(device.name, overflow: TextOverflow.ellipsis),
              subtitle: Text(device.state.label),
            ),
          ),
          if (action case (final icon, final label, final onPressed))
            MacosTooltip(
              message: label,
              child: MacosIconButton(
                icon: MacosIcon(icon, size: 16),
                semanticLabel: label,
                onPressed: onPressed,
              ),
            ),
        ],
      ),
    );
  }
}
