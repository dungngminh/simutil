import 'package:get_it/get_it.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_apple/simutil_apple.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_shared/simutil_shared.dart';

import 'devices/devices_cubit.dart';
import 'settings/view_settings_cubit.dart';
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
        slim: _SimulatorSlimControl(SimulatorSlimmer(getIt<CommandExec>())),
      ),
      dispose: (cubit) => cubit.close(),
    )
    ..registerLazySingleton<ViewSettingsCubit>(
      ViewSettingsCubit.new,
      dispose: (cubit) => cubit.close(),
    )
    ..registerLazySingleton<StreamsCubit>(
      () => StreamsCubit(
        defaultSessionFactory(
          exec: getIt<CommandExec>(),
          adbPath: () => getIt<AndroidDeviceService>().adbPath,
        ),
      ),
      dispose: (cubit) => cubit.close(),
    );
}

class _SimulatorSlimControl implements SlimControl {
  _SimulatorSlimControl(this._slimmer);

  final SimulatorSlimmer _slimmer;

  @override
  Future<bool> isSlim(String udid) => _slimmer.isSlim(udid);

  @override
  Future<void> setSlim(String udid, {required bool slim}) =>
      slim ? _slimmer.slim(udid) : _slimmer.unslim(udid);
}

/// Closes cubits and stops the shared [ServiceLocator].
Future<void> disposeDependencies() async {
  await getIt.reset();
  await ServiceLocator.instance.dispose();
}
