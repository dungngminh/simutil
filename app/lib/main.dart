import 'dart:io';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
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
import 'package:simutil_app/src/logging/debug_log.dart';
import 'package:simutil_app/src/mcp/mcp_server.dart';
import 'package:simutil_app/src/mcp/simutil_tools.dart';
import 'package:simutil_app/src/mcp/tools/tool_context.dart';
import 'package:simutil_app/src/recording/grid_recorder.dart';
import 'package:simutil_app/src/scenarios/scenario_runs_cubit.dart';
import 'package:simutil_app/src/settings/view_settings_cubit.dart';
import 'package:simutil_app/src/stream/ios/sim_camera.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_app/src/stream/touch_marks.dart';
import 'package:simutil_app/src/update/app_update_cubit.dart';
import 'package:simutil_app/src/windows/device_window_app.dart';
import 'package:simutil_app/src/windows/device_windows.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // A device window's engine starts with `multi_window <id> <arguments>`.
  if (args.firstOrNull == 'multi_window') {
    final window = await WindowController.fromCurrentEngine();
    if (DeviceWindows.deviceOf(window.arguments) case final device?) {
      return runDeviceWindow(window, device);
    }
  }
  await windowManager.ensureInitialized();
  await configureDependencies();
  final debugLog = getIt<DebugLog>();
  BlocSignalObserver.addObserver(
    BlocLogObserver(
      print: (line) {
        if (kDebugMode) debugPrint(line);
        debugLog.add(DebugSource.state, line);
      },
    ),
  );

  getIt<AppUpdateCubit>().check();
  final devices = getIt<DevicesCubit>()..start();
  final streams = getIt<StreamsCubit>();
  devices.state.subscribe((state) {
    streams.onDevices(state.all);
    SimCamera.onDevices(state.all);
  });
  // A device window sends its device back to the grid.
  await getIt<DeviceWindows>().listen((device) async {
    await windowManager.show(); // it may be hidden
    await windowManager.focus();
    await streams.open(device, here: true);
  });
  // Closing the window quits, after streams and recordings are released;
  // while device windows are open it only hides.
  final quitOnClose = _QuitOnClose(quitApp, getIt<DeviceWindows>());
  windowManager.addListener(quitOnClose);
  onWindowsChanged.listen((_) => quitOnClose.onWindowsChanged());
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
      log: (line, {error = false}) =>
          debugLog.add(DebugSource.mcp, line, error: error),
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

/// Runs [quit] when the main window is closed, or hides it while device
/// [windows] are open and quits once the last of them closes. The Dock icon
/// or a device window's "Back to the main window" shows it again.
class _QuitOnClose with WindowListener {
  _QuitOnClose(this.quit, this.windows);

  final Future<void> Function() quit;
  final DeviceWindows windows;
  var _quitting = false;

  /// Hidden by a close click (not minimized); shown again once focused.
  var _hidden = false;

  /// Quits once; further close clicks while quitting are ignored.
  @override
  Future<void> onWindowClose() async {
    if (_quitting) return;
    if (await windows.hasAny()) {
      _hidden = true;
      await windowManager.hide();
      return;
    }
    _quitting = true;
    await quit();
  }

  @override
  void onWindowFocus() => _hidden = false;

  /// A device window opened or closed.
  Future<void> onWindowsChanged() async {
    if (_quitting || !_hidden || await windows.hasAny()) return;
    if (await windowManager.isVisible()) return;
    _quitting = true;
    await quit();
  }
}
