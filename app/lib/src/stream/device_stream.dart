import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

/// Pointer phase sent to a device.
enum TouchPhase { down, move, up }

/// Navigation buttons a stream tile can send.
enum DeviceButton { back, home, recents, lock }

/// Lifecycle of one live device stream.
sealed class StreamStatus extends Equatable {
  const StreamStatus();

  @override
  List<Object?> get props => [];
}

final class StreamConnecting extends StreamStatus {
  const StreamConnecting();
}

final class StreamLive extends StreamStatus {
  const StreamLive(this.size);

  /// Device screen size in pixels, used for aspect ratio and touch mapping.
  final Size size;

  @override
  List<Object?> get props => [size];
}

final class StreamFailed extends StreamStatus {
  const StreamFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// A live view of one device's screen that also accepts input.
abstract interface class DeviceStream {
  /// Buttons this platform supports.
  List<DeviceButton> get buttons;

  /// Connects and starts streaming; reports progress through [onStatus].
  Future<void> start(void Function(StreamStatus status) onStatus);

  /// Stops streaming and releases every resource.
  Future<void> stop();

  /// The video surface.
  Widget buildView();

  /// Sends a touch at [position], normalized to 0..1 on both axes.
  void touch(TouchPhase phase, Offset position);

  /// Presses and releases [button].
  void press(DeviceButton button);
}
