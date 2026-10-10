import 'package:get_it/get_it.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_app/src/devices/slim_mode_cubit.dart';
import 'package:simutil_app/src/recording/recording_lock.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_app/src/recording/grid_recorder.dart';
import 'package:simutil_app/src/recording/saved_recordings.dart';
import 'package:simutil_app/src/settings/device_settings_cubit.dart';
import 'package:simutil_app/src/settings/view_settings_cubit.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_apple/simutil_apple.dart';
import 'package:simutil_core/simutil_core.dart';

/// App-wide service locator.
final getIt = GetIt.instance;

/// Starts the shell-command isolate and registers the device services plus
/// the app's cubits.
Future<void> configureDependencies() async {
  final isolateRunner = IsolateRunner();
  await isolateRunner.init();
  final exec = CommandExec.isolate(isolateRunner);

  getIt
    ..registerSingleton<IsolateRunner>(
      isolateRunner,
      dispose: (runner) => runner.dispose(),
    )
    ..registerSingleton<CommandExec>(exec)
    ..registerSingleton<AndroidDeviceService>(AndroidDeviceService(exec))
    ..registerLazySingleton<WifiDiscoveryService>(MdnsWifiDiscoveryService.new)
    ..registerLazySingleton<AdbWirelessPairing>(
      () => AdbWirelessPairing(
        getIt<AndroidDeviceService>(),
        getIt<WifiDiscoveryService>(),
      ),
    )
    ..registerSingleton<IOSDeviceService>(IOSDeviceService(exec))
    ..registerSingleton<XcodeCacheService>(XcodeCacheService(exec))
    ..registerLazySingleton<DevicesCubit>(
      () => DevicesCubit(
        android: getIt<AndroidDeviceService>(),
        ios: getIt<IOSDeviceService>(),
        slim: _SimulatorSlimControl(SimulatorSlimmer(getIt<CommandExec>())),
        // Late lookup: SlimModeCubit itself depends on DevicesCubit.
        slimOnLaunch: () => getIt<SlimModeCubit>().stateValue.enabled,
      ),
      dispose: (cubit) => cubit.close(),
    )
    ..registerLazySingleton<DeviceSettingsCubit>(
      DeviceSettingsCubit.new,
      dispose: (cubit) => cubit.close(),
    )
    ..registerSingleton<SavedRecordings>(
      SavedRecordings(exec),
      dispose: (saved) => saved.dispose(),
    )
    ..registerSingleton(RecordingLock())
    ..registerLazySingleton<GridRecorderCubit>(
      () => GridRecorderCubit(
        onSaved: getIt<SavedRecordings>().add,
        recordingLock: getIt<RecordingLock>(),
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
          settings: (device) => getIt<DeviceSettingsCubit>().of(device),
        ),
        onSaved: getIt<SavedRecordings>().add,
        recordingLock: getIt<RecordingLock>(),
      ),
      dispose: (cubit) => cubit.close(),
    )
    ..registerLazySingleton<SlimModeCubit>(
      () => SlimModeCubit(
        devices: getIt<DevicesCubit>(),
        streams: getIt<StreamsCubit>(),
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

/// Closes cubits and stops the shell-command isolate.
Future<void> disposeDependencies() => getIt.reset();
