import 'package:equatable/equatable.dart';
import 'package:simutil_core/simutil_core.dart';

/// One open tile in the stream grid.
final class StreamEntry extends Equatable {
  const StreamEntry({
    required this.device,
    required this.status,
    this.recording = false,
  });

  final Device device;
  final SessionStatus status;
  final bool recording;

  StreamEntry copyWith({SessionStatus? status, bool? recording}) => StreamEntry(
    device: device,
    status: status ?? this.status,
    recording: recording ?? this.recording,
  );

  @override
  List<Object?> get props => [device.id, status, recording];
}

/// Open streams in display order.
final class StreamsState extends Equatable {
  const StreamsState([this.entries = const []]);

  final List<StreamEntry> entries;

  bool isOpen(String deviceId) => entries.any((e) => e.device.id == deviceId);

  @override
  List<Object?> get props => [entries];
}
