import 'package:simutil/services/android_device_service.dart';
import 'package:simutil/services/command_exec.dart';
import 'package:simutil/services/ios_device_service.dart';
import 'package:simutil/services/isolate_runner.dart';
import 'package:simutil/services/settings_service.dart';

class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator _instance = ServiceLocator._();

  static ServiceLocator get instance => _instance;

  late final IsolateRunner isolateRunner = IsolateRunner();

  late final CommandExec commandExec = IsolateCommandExec(isolateRunner);

  late final AndroidDeviceService adbService = AndroidDeviceService(
    commandExec,
  );
  late final IOSDeviceService simctlService = IOSDeviceService(commandExec);
  late final SettingsService settingsService = SettingsService();

  Future<void> init() async => isolateRunner.init();

  Future<void> dispose() async => isolateRunner.dispose();
}
