import 'package:simutil/services/android_device_service.dart';
import 'package:simutil/services/app_state.dart';
import 'package:simutil/services/command_exec.dart';
import 'package:simutil/services/ios_device_service.dart';
import 'package:simutil/services/isolate_runner.dart';
import 'package:simutil/services/plugin_registry_service.dart';
import 'package:simutil/services/plugin_runner_service.dart';
import 'package:simutil/services/settings_service.dart';
import 'package:simutil/services/wifi_discovery_service.dart';

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
  late final SettingsService settingsService = SettingsServiceImpl(commandExec);
  late final AppStateService appStateService = AppStateServiceImpl();
  late final WifiDiscoveryService wifiDiscoveryService =
      MdnsWifiDiscoveryService();
  late final PluginRegistryService pluginRegistry = PluginRegistryServiceImpl();
  late final PluginRunnerService pluginRunner =
      PluginRunnerServiceImpl(commandExec);

  Future<void> init() async => isolateRunner.init();

  Future<void> dispose() async => isolateRunner.dispose();
}
