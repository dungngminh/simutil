import 'package:simutil/models/device_state.dart';
import 'package:simutil/models/device_type.dart';
import 'package:simutil/models/device_os.dart';

class Device {
  const Device({
    required this.id,
    required this.name,
    required this.os,
    required this.platform,
    required this.state,
    required this.type,
  });

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

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      os: DeviceOs.values.byName(json['type'] as String),
      platform: json['platform'] as String? ?? '',
      state: DeviceState.fromString(json['state'] as String? ?? 'Shutdown'),
      type: DeviceType.values.byName(json['type'] as String),
    );
  }

  final String id;

  final String name;

  final DeviceOs os;

  final String platform;

  final DeviceType type;

  final DeviceState state;

  bool get isRunning => state.isRunning;

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
