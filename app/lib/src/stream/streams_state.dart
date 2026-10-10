import 'package:equatable/equatable.dart';
import 'package:simutil_core/simutil_core.dart';

import 'device_stream.dart';

/// One open tile in the stream grid.
final class StreamEntry extends Equatable {
  const StreamEntry({required this.device, required this.status});

  final Device device;
  final StreamStatus status;

  StreamEntry withStatus(StreamStatus status) =>
      StreamEntry(device: device, status: status);

  @override
  List<Object?> get props => [device.id, status];
}

/// Open streams in display order.
final class StreamsState extends Equatable {
  const StreamsState([this.entries = const []]);

  final List<StreamEntry> entries;

  bool isOpen(String deviceId) => entries.any((e) => e.device.id == deviceId);

  @override
  List<Object?> get props => [entries];
}
