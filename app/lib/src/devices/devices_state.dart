import 'package:equatable/equatable.dart';
import 'package:simutil_core/simutil_core.dart';

/// Device lists shown in the tray and the main window.
final class DevicesState extends Equatable {
  const DevicesState({
    this.androidEmulators = const [],
    this.androidDevices = const [],
    this.iosSimulators = const [],
    this.iosDevices = const [],
    this.loading = false,
    this.slimmed = const {},
    this.busy = const {},
    this.message,
  });

  final List<Device> androidEmulators;
  final List<Device> androidDevices;
  final List<Device> iosSimulators;
  final List<Device> iosDevices;

  /// True while a refresh is running.
  final bool loading;

  /// Simulator UDIDs running slim.
  final Set<String> slimmed;

  /// Device ids with a start/stop/slim in progress.
  final Set<String> busy;

  /// Last status or error message, if any.
  final String? message;

  /// Every device, emulators/simulators first.
  List<Device> get all => [
    ...androidEmulators,
    ...iosSimulators,
    ...androidDevices,
    ...iosDevices,
  ];

  DevicesState copyWith({
    List<Device>? androidEmulators,
    List<Device>? androidDevices,
    List<Device>? iosSimulators,
    List<Device>? iosDevices,
    bool? loading,
    Set<String>? slimmed,
    Set<String>? busy,
    String? message,
  }) => DevicesState(
    androidEmulators: androidEmulators ?? this.androidEmulators,
    androidDevices: androidDevices ?? this.androidDevices,
    iosSimulators: iosSimulators ?? this.iosSimulators,
    iosDevices: iosDevices ?? this.iosDevices,
    loading: loading ?? this.loading,
    slimmed: slimmed ?? this.slimmed,
    busy: busy ?? this.busy,
    message: message ?? this.message,
  );

  @override
  List<Object?> get props => [
    _keys(androidEmulators),
    _keys(androidDevices),
    _keys(iosSimulators),
    _keys(iosDevices),
    loading,
    slimmed,
    busy,
    message,
  ];

  // ponytail: Device has no ==, compare by the fields the UI shows.
  static List<String> _keys(List<Device> devices) => [
    for (final d in devices) '${d.id}|${d.name}|${d.state.name}',
  ];
}
