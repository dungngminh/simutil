import 'package:simutil_core/src/models/device_os.dart';
import 'package:simutil_core/src/models/device_state.dart';
import 'package:simutil_core/src/models/device_type.dart';

/// A physical device, emulator, or simulator known to SimUtil.
class Device {
  /// Creates a device with explicit fields.
  const Device({
    required this.id,
    required this.name,
    required this.os,
    required this.platform,
    required this.state,
    required this.type,
  });

  /// Android emulator or hardware device (`os` is [DeviceOs.android]).
  factory Device.android({
    required String id,
    required String name,
    required DeviceState state,
    required DeviceType type,
  }) {
    return Device(
      id: id,
      name: name,
      platform: 'Android',
      os: DeviceOs.android,
      state: state,
      type: type,
    );
  }

  /// Apple family device (`os` is [DeviceOs.ios], including iPad/Watch/TV).
  factory Device.ios({
    required String id,
    required String name,
    String? platform,
    required DeviceState state,
    required DeviceType type,
  }) {
    return Device(
      id: id,
      name: name,
      platform: platform ?? 'iOS',
      os: DeviceOs.ios,
      state: state,
      type: type,
    );
  }

  /// Restores a [Device] from [toJson] output.
  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      os: DeviceOs.values.byName(json['os'] as String),
      platform: json['platform'] as String? ?? '',
      state: DeviceState.fromString(json['state'] as String? ?? 'Shutdown'),
      type: DeviceType.values.byName(json['type'] as String),
    );
  }

  /// Stable identifier (serial, AVD name, or UDID).
  final String id;

  /// Human-readable name.
  final String name;

  /// OS family used for filtering (Android vs Apple).
  final DeviceOs os;

  /// Display string such as `Android` or `iOS 17.2`.
  final String platform;

  /// Physical hardware vs emulator/simulator.
  final DeviceType type;

  /// Running, booting, or shut down.
  final DeviceState state;

  /// Whether [state] is booted or booting.
  bool get isRunning => state.isRunning;

  /// Returns a copy with selected fields replaced.
  Device copyWith({
    String? id,
    String? name,
    DeviceOs? os,
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

  /// Serializes this device for JSON persistence.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'os': os.name,
      'platform': platform,
      'state': state.label,
      'type': type.name,
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
