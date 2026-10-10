import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

import '../../devices/devices_cubit.dart';
import '../../settings/view_settings_cubit.dart';
import '../shared/responsive.dart';
import 'material_device_list.dart';
import 'material_stream_grid.dart';

/// Device list beside the stream grid; on narrow windows the list moves
/// into a drawer.
class MaterialHomePage extends StatelessWidget {
  const MaterialHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < kCompactWidth;
    final settings = context.value<ViewSettingsCubit, ViewSettings>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('SimUtil'),
        actions: [
          IconButton(
            tooltip: settings.headless
                ? 'Start devices headless (no own window)'
                : 'Start devices with their window',
            isSelected: settings.headless,
            icon: const Icon(Icons.desktop_windows_outlined),
            selectedIcon: const Icon(Icons.desktop_access_disabled_outlined),
            onPressed: context.read<ViewSettingsCubit>().toggleHeadless,
          ),
          IconButton(
            tooltip: settings.showFrames
                ? 'Hide device frames'
                : 'Show device frames',
            isSelected: settings.showFrames,
            icon: const Icon(Icons.crop_free),
            selectedIcon: const Icon(Icons.smartphone),
            onPressed: context.read<ViewSettingsCubit>().toggleFrames,
          ),
          IconButton(
            tooltip: 'Refresh devices',
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<DevicesCubit>().refresh(),
          ),
        ],
      ),
      drawer: compact ? const Drawer(child: MaterialDeviceList()) : null,
      body: compact
          ? const MaterialStreamGrid()
          : const Row(
              children: [
                SizedBox(width: 300, child: MaterialDeviceList()),
                VerticalDivider(width: 1),
                Expanded(child: MaterialStreamGrid()),
              ],
            ),
    );
  }
}
