import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../devices/devices_cubit.dart';
import '../../settings/view_settings_cubit.dart';
import '../shared/responsive.dart';
import 'macos_device_list.dart';
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
          // The sidebar hides itself below this window width; the toolbar
          // toggle brings it back.
          windowBreakpoint: kCompactWidth,
          builder: (context, scrollController) =>
              MacosDeviceList(scrollController: scrollController),
        ),
        child: const _MacosHome(),
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
    return MacosScaffold(
      toolBar: ToolBar(
        title: const Text('SimUtil'),
        actions: [
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
