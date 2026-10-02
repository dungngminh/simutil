import 'package:simutil_core/simutil_core.dart';

/// In-memory [DeviceService] returning fixed device lists.
///
/// Records [launched] and [shutdown] calls so tests can assert on routing.
class FakeDeviceService implements DeviceService {
  /// Creates a fake listing [simulators] and [physical] devices.
  FakeDeviceService({
    this.simulators = const [],
    this.physical = const [],
    this.available = true,
  });

  /// Returned by [getSimulators].
  List<Device> simulators;

  /// Returned by [getPhysicalDevices].
  List<Device> physical;

  /// Returned by [isAvailable].
  bool available;

  /// Recorded [launchDevice] calls, in order.
  final List<({String deviceId, List<String> args})> launched = [];

  /// Device ids passed to [shutdownSimulator], in order.
  final List<String> shutdown = [];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<Device>> getSimulators() async => simulators;

  @override
  Future<List<Device>> getPhysicalDevices() async => physical;

  @override
  Future<void> launchDevice({
    required String deviceId,
    List<String> additionalArgs = const [],
  }) async => launched.add((deviceId: deviceId, args: additionalArgs));

  @override
  Future<bool> shutdownSimulator({required String deviceId}) async {
    shutdown.add(deviceId);
    return true;
  }
}
