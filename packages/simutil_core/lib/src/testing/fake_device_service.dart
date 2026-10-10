import 'dart:async';

import 'package:simutil_core/simutil_core.dart';

/// In-memory [DeviceService] returning fixed device lists.
///
/// Records [launched], [shutdown] and [deleted] calls so tests can assert on routing.
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
  final List<({String deviceId, List<String> args, bool headless})> launched =
      [];

  /// Device ids passed to [shutdownSimulator], in order.
  final List<String> shutdown = [];

  /// Device ids passed to [deleteSimulator], in order.
  final List<String> deleted = [];

  final _changes = StreamController<void>.broadcast();

  /// Simulates the platform reporting a device change on [watchDevices].
  void emitDeviceChange() => _changes.add(null);

  @override
  Stream<void> watchDevices() => _changes.stream;

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
    bool headless = false,
  }) async => launched.add((
    deviceId: deviceId,
    args: additionalArgs,
    headless: headless,
  ));

  @override
  Future<bool> shutdownSimulator({required String deviceId}) async {
    shutdown.add(deviceId);
    return true;
  }

  @override
  Future<bool> deleteSimulator({required String deviceId}) async {
    deleted.add(deviceId);
    return true;
  }
}
