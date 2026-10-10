import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

import '../../devices/devices_cubit.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('SimUtil'),
        actions: [
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
