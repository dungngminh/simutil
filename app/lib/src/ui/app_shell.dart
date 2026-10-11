import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:simutil_app/src/scenarios/scenario_runs_cubit.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_app/src/ui/devices/device_sidebar.dart';
import 'package:simutil_app/src/ui/recording_toast.dart';
import 'package:simutil_app/src/ui/scenarios/scenarios_panel.dart';
import 'package:simutil_app/src/ui/shared/responsive.dart';
import 'package:simutil_app/src/ui/streams/stream_grid.dart';
import 'package:simutil_app/src/ui/top_bar.dart';

/// The app on every platform: one design system, light and dark.
class SimutilShell extends StatelessWidget {
  const SimutilShell({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SimUtil',
      debugShowCheckedModeBanner: false,
      theme: simuTheme(Brightness.light),
      darkTheme: simuTheme(Brightness.dark),
      builder: (context, child) => RecordingToastHost(child: child!),
      home: const _Home(),
    );
  }
}

/// Device sidebar beside the stream grid, and the scenarios panel on the
/// right once an agent runs one; narrow windows start with the sidebar
/// hidden.
class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  bool? _sidebarOpen;

  /// Null until the user toggles it: shown while there are runs.
  bool? _scenariosOpen;

  static const _sidebarWidth = 288.0;
  static const _scenariosWidth = 320.0;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < kCompactWidth;
    final open = _sidebarOpen ?? !compact;
    final hasRuns = context.select<ScenarioRunsCubit, bool>(
      (c) => c.stateValue.isNotEmpty,
    );
    final scenariosOpen = _scenariosOpen ?? hasRuns;
    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: open ? _sidebarWidth : 0,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerRight,
                minWidth: _sidebarWidth,
                maxWidth: _sidebarWidth,
                child: const DeviceSidebar(),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                TopBar(
                  sidebarOpen: open,
                  onToggleSidebar: () => setState(() => _sidebarOpen = !open),
                  scenariosOpen: scenariosOpen,
                  onToggleScenarios: () =>
                      setState(() => _scenariosOpen = !scenariosOpen),
                ),
                const Expanded(child: StreamGrid()),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: scenariosOpen ? _scenariosWidth : 0,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: _scenariosWidth,
                maxWidth: _scenariosWidth,
                child: ScenariosPanel(
                  onClose: () => setState(() => _scenariosOpen = false),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
