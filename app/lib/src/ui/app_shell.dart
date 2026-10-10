import 'package:flutter/material.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_app/src/ui/devices/device_sidebar.dart';
import 'package:simutil_app/src/ui/recording_toast.dart';
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

/// Device sidebar beside the stream grid; narrow windows start with the
/// sidebar hidden.
class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  bool? _sidebarOpen;

  static const _sidebarWidth = 288.0;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < kCompactWidth;
    final open = _sidebarOpen ?? !compact;
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
                ),
                const Expanded(child: StreamGrid()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
