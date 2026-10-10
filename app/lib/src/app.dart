import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_app/src/devices/slim_mode_cubit.dart';
import 'package:simutil_app/src/di.dart';
import 'package:simutil_app/src/recording/grid_recorder.dart';
import 'package:simutil_app/src/settings/device_settings_cubit.dart';
import 'package:simutil_app/src/settings/view_settings_cubit.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_app/src/ui/app_shell.dart';

/// Provides the cubits around the shared [SimutilShell].
class SimutilApp extends StatelessWidget {
  const SimutilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocSignalProvider(
      providers: [
        BlocSignalProvider<DevicesCubit>(create: (_) => getIt<DevicesCubit>()),
        BlocSignalProvider<StreamsCubit>(create: (_) => getIt<StreamsCubit>()),
        BlocSignalProvider<DeviceSettingsCubit>(
          create: (_) => getIt<DeviceSettingsCubit>(),
        ),
        BlocSignalProvider<GridRecorderCubit>(
          create: (_) => getIt<GridRecorderCubit>(),
        ),
        BlocSignalProvider<ViewSettingsCubit>(
          create: (_) => getIt<ViewSettingsCubit>(),
        ),
        BlocSignalProvider<SlimModeCubit>(
          create: (_) => getIt<SlimModeCubit>(),
        ),
      ],
      child: const SimutilShell(),
    );
  }
}
