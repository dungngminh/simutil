import 'package:simutil/models/device_state.dart';
import 'package:simutil/models/device_type.dart';
import 'package:simutil/models/os.dart';

/// Represents a simulator or emulator device.
class Device {

  const Device({
    required this.id,
    required this.name,
    required this.os,
    required this.platform,
    required this.state,
    required this.type,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      os: Os.values.byName(json['type'] as String),
      platform: json['platform'] as String? ?? '',
      state: DeviceState.fromString(json['state'] as String? ?? 'Shutdown'),
      type: DeviceType.values.byName(json['type'] as String),
    );
  }
  /// Unique identifier (AVD name for Android, UDID for iOS).
  final String id;

  /// Human-readable display name.
  final String name;

  /// Whether this is an Android or iOS device.
  final Os os;

  /// Platform/OS version info (e.g., "Android 14", "iOS 17.2").
  final String platform;

  /// Device type (physical or simulator).
  final DeviceType type;

  /// Current device state.
  final DeviceState state;

  /// Whether the device is currently running.
  bool get isRunning => state.isRunning;

  Device copyWith({
    String? id,
    String? name,
    Os? os,
    String? platform,
    DeviceState? state,
    DeviceType? type,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      os: os ?? this.os,
      platform: platform ?? this.platform,
      state: state ?? this.state,
      type: type ?? this.type,

    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': os.name,
      'platform': platform,
      'state': state.label,
    };
  }

  @override
  String toString() => 'Device($name, $os, $state)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          os == other.os &&
          platform == other.platform &&
          state == other.state;

  @override
  int get hashCode => Object.hash(id, name, os, platform, state);
}
