import 'package:simutil/services/app_state.dart';
import 'package:simutil/services/settings_service.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_apple/simutil_apple.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_plugins/simutil_plugins.dart';

/// Wires TUI services: core exec, adb, Apple, settings, and plugins.
class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator _instance = ServiceLocator._();

  /// Shared locator used by the TUI.
  static ServiceLocator get instance => _instance;

  /// Background isolate that runs shell commands.
  late final IsolateRunner isolateRunner = IsolateRunner();

  /// TUI [CommandExec] that delegates to [isolateRunner].
  late final CommandExec commandExec = IsolateCommandExec(isolateRunner);

  /// Android emulators and hardware via adb.
  late final AndroidDeviceService adbService = AndroidDeviceService(
    commandExec,
  );

  /// Apple simulators and hardware via simctl/devicectl.
  late final IOSDeviceService simctlService = IOSDeviceService(commandExec);

  /// Theme and last-selected-device scalars.
  late final SettingsService settingsService = SettingsServiceImpl(commandExec);

  /// First-run / changelog version state.
  late final AppStateService appStateService = AppStateServiceImpl();

  /// mDNS watcher for wireless ADB pairing.
  late final WifiDiscoveryService wifiDiscoveryService =
      MdnsWifiDiscoveryService();

  /// YAML plugin registry.
  late final PluginRegistryService pluginRegistry = PluginRegistryServiceImpl();

  /// Launches plugin commands as external processes.
  late final PluginRunnerService pluginRunner = PluginRunnerServiceImpl(
    commandExec,
  );

  /// Xcode Derived Data size/clear.
  late final XcodeCacheService xcodeCacheService = XcodeCacheService(
    commandExec,
  );

  /// Starts [isolateRunner].
  Future<void> init() async => isolateRunner.init();

  /// Stops [isolateRunner].
  Future<void> dispose() async => isolateRunner.dispose();
}

