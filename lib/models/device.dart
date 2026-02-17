import 'device_state.dart';
import 'device_type.dart';

/// Represents a simulator or emulator device.
class Device {
  /// Unique identifier (AVD name for Android, UDID for iOS).
  final String id;

  /// Human-readable display name.
  final String name;

  /// Whether this is an Android or iOS device.
  final DeviceType type;

  /// Platform/OS version info (e.g., "Android 14", "iOS 17.2").
  final String platform;

  /// Current device state.
  final DeviceState state;

  const Device({
    required this.id,
    required this.name,
    required this.type,
    required this.platform,
    required this.state,
  });

  /// Whether the device is currently running.
  bool get isRunning => state.isRunning;

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      type: DeviceType.values.byName(json['type'] as String),
      platform: json['platform'] as String? ?? '',
      state: DeviceState.fromString(json['state'] as String? ?? 'Shutdown'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'platform': platform,
      'state': state.label,
    };
  }

  @override
  String toString() => 'Device($name, $type, $state)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type;

  @override
  int get hashCode => Object.hash(id, type);
}
