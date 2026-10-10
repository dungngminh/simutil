import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../devices/devices_cubit.dart';
import '../../recording/grid_recorder.dart';
import '../../settings/recordings_dir.dart';
import '../../settings/view_settings_cubit.dart';
import '../shared/responsive.dart';
import 'macos_device_list.dart';
import 'macos_recording_toast.dart';
import 'macos_stream_grid.dart';

/// Applies the unified toolbar window style; call before `runApp` on macOS.
Future<void> configureMacosWindow() => const MacosWindowUtilsConfig(
  toolbarStyle: NSWindowToolbarStyle.unified,
).apply();

/// macOS: native look via macos_ui.
class MacosSimutilApp extends StatelessWidget {
  const MacosSimutilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MacosApp(
      title: 'SimUtil',
      debugShowCheckedModeBanner: false,
      theme: MacosThemeData.light(),
      darkTheme: MacosThemeData.dark(),
      home: MacosWindow(
        sidebar: Sidebar(
          minWidth: 240,
          startWidth: 280,
          windowBreakpoint: kCompactWidth,
          builder: (context, scrollController) =>
              MacosDeviceList(scrollController: scrollController),
        ),
        child: const MacosRecordingToastHost(child: _MacosHome()),
      ),
    );
  }
}

class _MacosHome extends StatelessWidget {
  const _MacosHome();

  @override
  Widget build(BuildContext context) {
    final settings = context.value<ViewSettingsCubit, ViewSettings>();
    final cubit = context.read<ViewSettingsCubit>();
    final recorder = context.read<GridRecorderCubit>();
    final recordingGrid = context.value<GridRecorderCubit, bool>();
    return MacosScaffold(
      toolBar: ToolBar(
        title: const Text('SimUtil'),
        actions: [
          ToolBarIconButton(
            label: 'Record grid',
            tooltipMessage: recordingGrid
                ? 'Stop recording grid'
                : 'Record grid to ~/Movies/SimUtil',
            icon: MacosIcon(
              recordingGrid
                  ? CupertinoIcons.stop_circle_fill
                  : CupertinoIcons.video_camera,
              color: recordingGrid ? MacosColors.systemRedColor : null,
            ),
            showLabel: false,
            onPressed: () async {
              if (recorder.isRecording) {
                await recorder.stop();
              } else {
                final stamp = DateTime.now().toIso8601String().replaceAll(
                  ':',
                  '-',
                );
                await recorder
                    .start('${recordingsDirectory()}/simutil-grid-$stamp.mp4')
                    .catchError((Object _) {});
              }
            },
          ),
          ToolBarIconButton(
            label: 'Headless',
            tooltipMessage: settings.headless
                ? 'Starting devices headless (no own window)'
                : 'Starting devices with their window',
            icon: MacosIcon(
              settings.headless
                  ? CupertinoIcons.eye_slash
                  : CupertinoIcons.macwindow,
            ),
            showLabel: false,
            onPressed: cubit.toggleHeadless,
          ),
          ToolBarIconButton(
            label: 'Frames',
            tooltipMessage: settings.showFrames
                ? 'Hide device frames'
                : 'Show device frames',
            icon: MacosIcon(
              settings.showFrames
                  ? CupertinoIcons.device_phone_portrait
                  : CupertinoIcons.rectangle,
            ),
            showLabel: false,
            onPressed: cubit.toggleFrames,
          ),
          ToolBarIconButton(
            label: 'Refresh',
            tooltipMessage: 'Refresh devices',
            icon: const MacosIcon(CupertinoIcons.refresh),
            showLabel: false,
            onPressed: () => context.read<DevicesCubit>().refresh(),
          ),
        ],
      ),
      children: [ContentArea(builder: (context, _) => const MacosStreamGrid())],
    );
  }
}
