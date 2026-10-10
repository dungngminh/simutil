import 'dart:io';

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/widgets.dart';

import 'devices/devices_cubit.dart';
import 'di.dart';
import 'recording/grid_recorder.dart';
import 'settings/view_settings_cubit.dart';
import 'stream/streams_cubit.dart';
import 'ui/macos/macos_simutil_app.dart';
import 'ui/material/material_app.dart';

/// Provides the cubits, then picks the platform design: macos_ui on macOS,
/// Material on Windows and Linux.
class SimutilApp extends StatelessWidget {
  const SimutilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocSignalProvider(
      providers: [
        BlocSignalProvider<DevicesCubit>.value(value: getIt<DevicesCubit>()),
        BlocSignalProvider<StreamsCubit>.value(value: getIt<StreamsCubit>()),
        BlocSignalProvider<GridRecorderCubit>.value(
          value: getIt<GridRecorderCubit>(),
        ),
        BlocSignalProvider<ViewSettingsCubit>.value(
          value: getIt<ViewSettingsCubit>(),
        ),
      ],
      child: Platform.isMacOS
          ? const MacosSimutilApp()
          : const MaterialSimutilApp(),
    );
  }
}
