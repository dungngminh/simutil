import 'dart:io';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_apple/simutil_apple.dart';
import 'package:window_manager/window_manager.dart';

import 'package:simutil_app/src/devices/slim_mode_cubit.dart';
import 'package:simutil_app/src/app.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_app/src/di.dart';
import 'package:simutil_app/src/logging/bloc_log.dart';
import 'package:simutil_app/src/mcp/mcp_server.dart';
import 'package:simutil_app/src/mcp/simutil_tools.dart';
import 'package:simutil_app/src/recording/grid_recorder.dart';
import 'package:simutil_app/src/settings/device_settings_cubit.dart';
import 'package:simutil_app/src/settings/view_settings_cubit.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_app/src/tray/tray_controller.dart';

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
  final tray = getIt.registerSingleton(
    TrayController(
      devices: devices,
      streams: streams,
      deviceSettings: getIt<DeviceSettingsCubit>(),
      viewSettings: getIt<ViewSettingsCubit>(),
      xcodeCache: getIt<XcodeCacheService>(),
      onQuit: () async {
        await disposeDependencies();
        await windowManager.destroy();
      },
    ),
  );
  await tray.init();

  final mcp = getIt.registerSingleton(
    McpServer(
      port:
          int.tryParse(Platform.environment['SIMUTIL_MCP_PORT'] ?? '') ?? 8765,
      tools: simutilTools(
        devices: devices,
        streams: streams,
        grid: getIt<GridRecorderCubit>(),
        view: getIt<ViewSettingsCubit>(),
        slim: getIt<SlimModeCubit>(),
        adbPath: () => getIt<AndroidDeviceService>().adbPath,
      ),
    ),
  );
  try {
    await mcp.start();
    tray.mcpUrl = mcp.url;
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
