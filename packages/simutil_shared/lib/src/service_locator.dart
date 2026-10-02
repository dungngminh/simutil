import 'package:simutil_shared/src/app_state.dart';
import 'package:simutil_shared/src/settings_service.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_apple/simutil_apple.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_plugins/simutil_plugins.dart';

/// Wires app services (core exec, adb, Apple, settings, plugins) shared by
/// the TUI and the GUI.
class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator _instance = ServiceLocator._();

  /// Shared locator instance.
  static ServiceLocator get instance => _instance;

  /// Background isolate that runs shell commands.
  late final IsolateRunner isolateRunner = IsolateRunner();

  /// [CommandExec] that delegates to [isolateRunner] off the UI isolate.
  late final CommandExec commandExec = IsolateCommandExec(isolateRunner);

  /// Android emulators and hardware via adb.
  late final AndroidDeviceService adbService = AndroidDeviceService(
    commandExec,
  );

  /// Apple simulators and hardware via simctl/devicectl.
  late final IOSDeviceService simctlService = IOSDeviceService(commandExec);

  /// Theme and last-selected-device scalars.
  late final SettingsService settingsService = SettingsService(commandExec);

  /// First-run / changelog version state.
  late final AppStateService appStateService = AppStateService();

  /// mDNS watcher for wireless ADB pairing.
  late final WifiDiscoveryService wifiDiscoveryService =
      MdnsWifiDiscoveryService();

  /// Reads the YAML plugin catalog from `~/.simutil/settings.yaml`.
  final PluginCatalogLoader pluginCatalogLoader = loadPluginCatalog;

  /// Launches plugin commands as external processes.
  late final PluginRunner pluginRunner = PluginRunner(commandExec);

  /// Xcode Derived Data size/clear.
  late final XcodeCacheService xcodeCacheService = XcodeCacheService(
    commandExec,
  );

  /// Starts [isolateRunner].
  Future<void> init() async => isolateRunner.init();

  /// Stops [isolateRunner].
  Future<void> dispose() async => isolateRunner.dispose();
}
