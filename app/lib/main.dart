import 'dart:io';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:window_manager/window_manager.dart';

import 'package:simutil_app/src/automation/app_automation.dart';
import 'package:simutil_app/src/devices/slim_mode_cubit.dart';
import 'package:simutil_app/src/app.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_app/src/di.dart';
import 'package:simutil_app/src/logging/bloc_log.dart';
import 'package:simutil_app/src/mcp/mcp_server.dart';
import 'package:simutil_app/src/mcp/simutil_tools.dart';
import 'package:simutil_app/src/mcp/tools/tool_context.dart';
import 'package:simutil_app/src/recording/grid_recorder.dart';
import 'package:simutil_app/src/scenarios/scenario_runs_cubit.dart';
import 'package:simutil_app/src/settings/view_settings_cubit.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_app/src/stream/touch_marks.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  if (kDebugMode) {
    BlocSignalObserver.addObserver(BlocLogObserver());
  }
  await configureDependencies();

  final devices = getIt<DevicesCubit>()..start();
  final streams = getIt<StreamsCubit>();
  devices.state.subscribe((state) => streams.onDevices(state.all));
  // Closing the window quits, after streams and recordings are released.
  windowManager.addListener(
    _QuitOnClose(() async {
      try {
        await disposeDependencies();
      } catch (e, s) {
        debugPrint('Dispose on quit failed: $e\n$s');
      } finally {
        await windowManager.destroy();
      }
    }),
  );
  await windowManager.setPreventClose(true);

  // Shared by the MCP tools and the scenario editor.
  final tools = getIt.registerSingleton(
    ToolContext(
      devices: devices,
      streams: streams,
      grid: getIt<GridRecorderCubit>(),
      view: getIt<ViewSettingsCubit>(),
      slim: getIt<SlimModeCubit>(),
      adbPath: () => getIt<AndroidDeviceService>().adbPath,
      automation: appAutomation(
        exec: getIt<CommandExec>(),
        adbPath: () => getIt<AndroidDeviceService>().adbPath,
        session: streams.sessionFor,
      ),
      marks: getIt<TouchMarks>(),
      runs: getIt<ScenarioRunsCubit>(),
    ),
  );
  final mcp = getIt.registerSingleton(
    McpServer(
      port:
          int.tryParse(Platform.environment['SIMUTIL_MCP_PORT'] ?? '') ?? 8765,
      tools: simutilTools(tools),
    ),
  );
  try {
    await mcp.start();
  } on SocketException catch (e) {
    debugPrint('MCP server not started: $e');
  }

  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      title: 'SimUtil',
      size: Size(1280, 800),
      minimumSize: Size(720, 480),
      center: true,
      // macOS keeps the traffic lights over our own top bar; Windows and
      // Linux keep their native caption buttons.
      titleBarStyle: Platform.isMacOS
          ? TitleBarStyle.hidden
          : TitleBarStyle.normal,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  runApp(const SimutilApp());
}

/// Runs [quit] when the main window is closed.
class _QuitOnClose with WindowListener {
  _QuitOnClose(this.quit);

  final Future<void> Function() quit;
  var _quitting = false;

  /// Quits once; further close clicks while quitting are ignored.
  @override
  Future<void> onWindowClose() async {
    if (_quitting) return;
    _quitting = true;
    await quit();
  }
}
