import 'package:equatable/equatable.dart';
import 'package:simutil_core/simutil_core.dart';

/// One open tile in the stream grid.
final class StreamEntry extends Equatable {
  /// Creates a tile for [device].
  const StreamEntry({
    required this.device,
    required this.status,
    this.recordingSince,
  });

  /// The streamed device.
  final Device device;

  /// Latest session status.
  final SessionStatus status;

  /// When the current recording started; null when not recording.
  final DateTime? recordingSince;

  /// Whether the tile is recording.
  bool get recording => recordingSince != null;

  /// Copy with the given fields replaced.
  StreamEntry copyWith({
    SessionStatus? status,
    DateTime? Function()? recordingSince,
  }) => StreamEntry(
    device: device,
    status: status ?? this.status,
    recordingSince: recordingSince != null
        ? recordingSince()
        : this.recordingSince,
  );

  @override
  List<Object?> get props => [device.id, status, recordingSince];
}

/// Open streams in display order.
final class StreamsState extends Equatable {
  /// Creates the state with [entries].
  const StreamsState([this.entries = const []]);

  /// Open tiles in display order.
  final List<StreamEntry> entries;

  /// Whether [deviceId] has a tile.
  bool isOpen(String deviceId) => entries.any((e) => e.device.id == deviceId);

  @override
  List<Object?> get props => [entries];
}
