import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';
import 'src/devices/devices_cubit.dart';
import 'src/di.dart';
import 'src/tray/tray_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();
  await configureDependencies();

  final devices = getIt<DevicesCubit>()..start();
  await TrayController(
    devices,
    onQuit: () async {
      await disposeDependencies();
      await windowManager.destroy();
    },
  ).init();

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
