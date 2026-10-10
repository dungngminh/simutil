import 'package:get_it/get_it.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_apple/simutil_apple.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_shared/simutil_shared.dart';

import 'devices/devices_cubit.dart';
import 'stream/streams_cubit.dart';

/// App-wide service locator.
final getIt = GetIt.instance;

/// Starts the shared [ServiceLocator] and registers its services plus the
/// app's cubits.
Future<void> configureDependencies() async {
  final locator = ServiceLocator.instance;
  await locator.init();

  getIt
    ..registerSingleton<CommandExec>(locator.commandExec)
    ..registerSingleton<AndroidDeviceService>(locator.adbService)
    ..registerSingleton<IOSDeviceService>(locator.simctlService)
    ..registerLazySingleton<DevicesCubit>(
      () => DevicesCubit(
        android: getIt<AndroidDeviceService>(),
        ios: getIt<IOSDeviceService>(),
      ),
      dispose: (cubit) => cubit.close(),
    )
    ..registerLazySingleton<StreamsCubit>(
      () => StreamsCubit(
        defaultStreamFactory(
          exec: getIt<CommandExec>(),
          adbPath: () => getIt<AndroidDeviceService>().adbPath,
        ),
      ),
      dispose: (cubit) => cubit.close(),
    );
}

/// Closes cubits and stops the shared [ServiceLocator].
Future<void> disposeDependencies() async {
  await getIt.reset();
  await ServiceLocator.instance.dispose();
}
