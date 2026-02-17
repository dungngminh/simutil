import 'package:simutil/services/adb_service.dart';
import 'package:simutil/services/command_exec.dart';
import 'package:simutil/services/settings_service.dart';
import 'package:simutil/services/simctl_service.dart';

/// Simple service locator / DI container for SimUtil.
///
/// Usage:
/// ```dart
/// final di = ServiceLocator.instance;
/// final result = await di.deviceRefreshService.refreshAll();
/// ```
class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator _instance = ServiceLocator._();

  /// Global singleton instance.
  static ServiceLocator get instance => _instance;

  // ── Core ────────────────────────────────────────────────────

  late final CommandExec commandExec = CommandExecImpl();

  // ── Services ────────────────────────────────────────────────

  late final AdbService adbService = AdbService(commandExec);
  late final SimctlService simctlService = SimctlService(commandExec);
  late final SettingsService settingsService = SettingsService();
}
