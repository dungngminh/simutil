import 'package:simutil/services/android_device_service.dart';
import 'package:simutil/services/command_exec.dart';
import 'package:simutil/services/ios_device_service.dart';
import 'package:simutil/services/isolate_runner.dart';
import 'package:simutil/services/settings_service.dart';

/// Simple service locator / DI container for SimUtil.
///
/// Usage:
/// ```dart
/// final di = ServiceLocator.instance;
/// await di.init(); // spawns the background isolate
/// final devices = await di.adbService.listDevices();
/// await di.dispose(); // shuts it down
/// ```
class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator _instance = ServiceLocator._();

  /// Global singleton instance.
  static ServiceLocator get instance => _instance;

  // ── Core ────────────────────────────────────────────────────

  /// Long-lived background isolate for CLI commands.
  late final IsolateRunner isolateRunner = IsolateRunner();

  /// Command executor that delegates to the background isolate.
  late final CommandExec commandExec = IsolateCommandExec(isolateRunner);

  // ── Services ────────────────────────────────────────────────

  late final AndroidDeviceService adbService = AndroidDeviceService(
    commandExec,
  );
  late final IOSDeviceService simctlService = IOSDeviceService(commandExec);
  late final SettingsService settingsService = SettingsService();

  // ── Lifecycle ───────────────────────────────────────────────

  /// Initialise services that require async setup (background isolate).
  Future<void> init() async => isolateRunner.init();

  /// Tear down services (kills the background isolate).
  Future<void> dispose() async => isolateRunner.dispose();
}
