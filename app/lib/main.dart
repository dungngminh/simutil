import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';
import 'src/devices/devices_cubit.dart';
import 'src/di.dart';
import 'src/mcp/mcp_server.dart';
import 'src/mcp/simutil_tools.dart';
import 'src/recording/grid_recorder.dart';
import 'src/stream/streams_cubit.dart';
import 'src/tray/tray_controller.dart';
import 'src/ui/macos/macos_simutil_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();
  if (Platform.isMacOS) await configureMacosWindow();
  await configureDependencies();

  final devices = getIt<DevicesCubit>()..start();
  final streams = getIt<StreamsCubit>();
  devices.state.subscribe((state) => streams.onDevices(state.all));
  // Registered so it stays reachable: a collected TrayIcon removes itself.
  final tray = getIt.registerSingleton(
    TrayController(
      devices,
      onQuit: () async {
        await disposeDependencies();
        await windowManager.destroy();
      },
    ),
  );
  await tray.init();

  final mcp = McpServer(
    port: int.tryParse(Platform.environment['SIMUTIL_MCP_PORT'] ?? '') ?? 8765,
    tools: simutilTools(
      devices: devices,
      streams: streams,
      grid: getIt<GridRecorderCubit>(),
      adbPath: () => getIt<AndroidDeviceService>().adbPath,
    ),
  );
  try {
    await mcp.start();
    tray.mcpUrl = mcp.url;
  } on SocketException catch (e) {
    debugPrint('MCP server not started: $e');
  }

  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'SimUtil',
      size: Size(1280, 800),
      minimumSize: Size(720, 480),
      center: true,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  runApp(const SimutilApp());
}
