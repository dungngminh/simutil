import 'dart:io';

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_app/src/di.dart';
import 'package:simutil_app/src/logging/debug_log.dart';
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
                    ('Android devices', state.androidDevices),
                    ('Android emulators', state.androidEmulators),
                    ('iOS devices', state.iosDevices),
                    ('iOS simulators', state.iosSimulators),
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

/// Logo and name; tapping the logo five times in a row toggles the debug
/// panel.
class _Brand extends StatefulWidget {
  const _Brand();

  @override
  State<_Brand> createState() => _BrandState();
}

class _BrandState extends State<_Brand> {
  static const _taps = 5;
  static const _window = Duration(seconds: 2);
  final _tapTimes = <DateTime>[];

  void _onLogoTap() {
    final now = DateTime.now();
    _tapTimes
      ..removeWhere((t) => now.difference(t) > _window)
      ..add(now);
    if (_tapTimes.length < _taps) return;
    _tapTimes.clear();
    getIt<DebugLog>().toggle();
  }

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    // The drag area sits behind the logo: its double-tap (maximize) would
    // otherwise swallow the logo taps.
    return Stack(
      children: [
        const Positioned.fill(child: DragToMoveArea(child: SizedBox.expand())),
        Padding(
          // macOS draws the traffic lights over the top of the sidebar.
          padding: EdgeInsets.fromLTRB(14, Platform.isMacOS ? 40 : 14, 14, 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: _onLogoTap,
                child: Image.asset(
                  'assets/logo.png',
                  width: 24,
                  height: 24,
                  filterQuality: FilterQuality.medium,
                  semanticLabel: 'SimUtil',
                ),
              ),
              const SizedBox(width: 10),
              Text('SimUtil', style: t.title),
            ],
          ),
        ),
      ],
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
