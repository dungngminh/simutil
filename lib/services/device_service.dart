import 'package:simutil/models/device.dart';

abstract class DeviceService {
  Future<bool> isAvailable();

  Future<List<Device>> getPhysicalDevices();

  Future<List<Device>> getSimulators();

  Future<void> launchDevice({
    required String deviceId,
    List<String> additionalArgs = const [],
  });
}
