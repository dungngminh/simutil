import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_plugins/simutil_plugins.dart';

/// [PluginRunner] that never spawns processes.
///
/// Reports [available] for every probe and returns [result] from [run],
/// recording each launched command in [ran].
class FakePluginRunner implements PluginRunner {
  /// Creates a fake runner; defaults to available and successful.
  FakePluginRunner({
    this.available = true,
    this.result = const PluginRunResult(success: true, message: 'started'),
  });

  /// Returned by [isAvailable].
  bool available;

  /// Returned by [run].
  PluginRunResult result;

  /// Commands passed to [run], with their target device.
  final List<({PluginCommandConfig command, Device? device})> ran = [];

  @override
  Future<bool> isAvailable(
    PluginConfig plugin,
    PluginCommandConfig command,
  ) async => available;

  @override
  Future<PluginRunResult> run(
    PluginCommandConfig command,
    Device? device,
  ) async {
    ran.add((command: command, device: device));
    return result;
  }
}
