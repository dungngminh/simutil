import 'dart:io';

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_app/src/ui/connect/connect_dialog.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_app/src/devices/devices_state.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_app/src/ui/devices/device_row.dart';
import 'package:simutil_app/src/ui/devices/device_search_field.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:window_manager/window_manager.dart';

/// Brand header, search and refresh, and the device sections.
class DeviceSidebar extends StatefulWidget {
  const DeviceSidebar({super.key});

  @override
  State<DeviceSidebar> createState() => _DeviceSidebarState();
}

class _DeviceSidebarState extends State<DeviceSidebar> {
  String _query = '';

  List<Device> _filter(List<Device> devices) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return devices;
    return [
      for (final d in devices)
        if (d.name.toLowerCase().contains(query)) d,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.sidebar,
        border: Border(right: BorderSide(color: t.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Brand(),
          _SearchRow(onChanged: (query) => setState(() => _query = query)),
          Expanded(
            child: BlocSignalBuilder<DevicesCubit, DevicesState>(
              builder: (context, state) => ListView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                children: [
                  if (state.loading)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: SimuSpinner()),
                    ),
                  for (final (title, devices) in [
                    ('Android emulators', state.androidEmulators),
                    ('Android devices', state.androidDevices),
                    ('iOS simulators', state.iosSimulators),
                    ('iOS devices', state.iosDevices),
                  ])
                    _Section(title, _filter(devices), state),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 8, 4),
      child: Row(
        children: [
          Expanded(child: DeviceSearchField(onChanged: onChanged)),
          const SizedBox(width: 4),
          SimuIconButton(
            icon: LucideIcons.wifi,
            tooltip: 'Connect a device over Wi-Fi',
            size: 15,
            onPressed: () => showConnectDeviceDialog(context),
          ),
          SimuIconButton(
            icon: LucideIcons.refreshCw,
            tooltip: 'Refresh devices',
            size: 15,
            onPressed: () => context.read<DevicesCubit>().refresh(),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return DragToMoveArea(
      child: Padding(
        // macOS draws the traffic lights over the top of the sidebar.
        padding: EdgeInsets.fromLTRB(14, Platform.isMacOS ? 40 : 14, 14, 10),
        child: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              width: 24,
              height: 24,
              filterQuality: FilterQuality.medium,
              semanticLabel: 'SimUtil',
            ),
            const SizedBox(width: 10),
            Text('SimUtil', style: t.title),
          ],
        ),
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
    final t = SimuTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
          child: Row(
            children: [
              Expanded(child: Text(title.toUpperCase(), style: t.overline)),
              Text('${devices.length}', style: t.mono.copyWith(fontSize: 11)),
            ],
          ),
        ),
        for (final device in devices) DeviceRow(device: device, state: state),
      ],
    );
  }
}
