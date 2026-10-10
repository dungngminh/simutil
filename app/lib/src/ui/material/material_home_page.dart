import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

import '../../devices/devices_cubit.dart';
import '../../recording/grid_recorder.dart';
import '../../settings/recordings_dir.dart';
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
    final recordingGrid = context.value<GridRecorderCubit, bool>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('SimUtil'),
        actions: [
          IconButton(
            tooltip: recordingGrid ? 'Stop recording grid' : 'Record grid',
            icon: Icon(
              recordingGrid ? Icons.stop_circle : Icons.videocam_outlined,
              color: recordingGrid ? Colors.red : null,
            ),
            onPressed: () => _toggleGridRecording(context),
          ),
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

  Future<void> _toggleGridRecording(BuildContext context) async {
    final recorder = context.read<GridRecorderCubit>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (recorder.isRecording) {
        final path = await recorder.stop();
        messenger.showSnackBar(SnackBar(content: Text('Saved $path')));
      } else {
        final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
        await recorder.start(
          '${recordingsDirectory()}/simutil-grid-$stamp.mp4',
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
