import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_app/src/devices/slim_mode_cubit.dart';
import 'package:simutil_app/src/di.dart';
import 'package:simutil_app/src/recording/grid_recorder.dart';
import 'package:simutil_app/src/scenarios/scenario_runs_cubit.dart';
import 'package:simutil_app/src/settings/device_settings_cubit.dart';
import 'package:simutil_app/src/settings/view_settings_cubit.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_app/src/ui/app_shell.dart';
import 'package:simutil_app/src/update/app_update_cubit.dart';

/// Provides the cubits around [child]: the shared [SimutilShell], or a
/// device window's own app.
class SimutilApp extends StatelessWidget {
  const SimutilApp({super.key, this.child = const SimutilShell()});

  final Widget child;

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
        BlocSignalProvider<ScenarioRunsCubit>(
          create: (_) => getIt<ScenarioRunsCubit>(),
        ),
        BlocSignalProvider<SlimModeCubit>(
          create: (_) => getIt<SlimModeCubit>(),
        ),
        BlocSignalProvider<AppUpdateCubit>(
          create: (_) => getIt<AppUpdateCubit>(),
        ),
      ],
      child: child,
    );
  }
}
