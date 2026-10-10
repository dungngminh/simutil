/// Pointer phase of a touch sent to a device.
enum TouchPhase {
  /// Finger down.
  down,

  /// Finger moved while down.
  move,

  /// Finger lifted.
  up,
}

/// Navigation and hardware buttons a session can press.
enum DeviceButton {
  /// Android back.
  back,

  /// Home screen.
  home,

  /// Recent apps / app switcher.
  recents,

  /// Lock / power button.
  lock,

  /// Volume up side button.
  volumeUp,

  /// Volume down side button.
  volumeDown,
}

/// Lifecycle of a [DeviceSession].
sealed class SessionStatus {
  const SessionStatus();
}

/// Connecting to the device; no frames yet.
final class SessionConnecting extends SessionStatus {
  /// Creates the connecting status.
  const SessionConnecting();

  @override
  bool operator ==(Object other) => other is SessionConnecting;

  @override
  int get hashCode => (SessionConnecting).hashCode;
}

/// Streaming a [width]x[height] screen (pixels).
final class SessionLive extends SessionStatus {
  /// Creates a live status for a [width]x[height] screen.
  const SessionLive({
    required this.width,
    required this.height,
    this.inputBlocked = false,
  });

  /// Screen width in pixels.
  final int width;

  /// Screen height in pixels.
  final int height;

  /// Video works but input is cut off until [DeviceSession.repairInput].
  final bool inputBlocked;

  @override
  bool operator ==(Object other) =>
      other is SessionLive &&
      other.width == width &&
      other.height == height &&
      other.inputBlocked == inputBlocked;

  @override
  int get hashCode => Object.hash(width, height, inputBlocked);
}

/// The session stopped with a user-facing [message].
final class SessionFailed extends SessionStatus {
  /// Creates a failed status with a user-facing [message].
  const SessionFailed(this.message);

  /// Why the session stopped.
  final String message;

  @override
  bool operator ==(Object other) =>
      other is SessionFailed && other.message == message;

  @override
  int get hashCode => message.hashCode;
}

/// A live connection to one device's screen: status, input and recording.
abstract interface class DeviceSession {
  /// Device id (adb serial or simulator UDID).
  String get deviceId;

  /// Buttons [press] supports on this platform.
  List<DeviceButton> get buttons;

  /// Status changes; [status] holds the latest.
  Stream<SessionStatus> get statusChanges;

  /// Latest status.
  SessionStatus get status;

  /// Connects and starts streaming.
  Future<void> start();

  /// Stops streaming and recording and releases every resource.
  Future<void> stop();

  /// Sends a touch at ([x], [y]), normalized to 0..1.
  void touch(TouchPhase phase, double x, double y);

  /// Presses and releases [button].
  void press(DeviceButton button);

  /// Restores input when [SessionLive.inputBlocked]; may restart apps.
  Future<void> repairInput();

  /// Whether [startRecording] is active.
  bool get isRecording;

  /// Records the screen to [path] (`.mp4`) until [stopRecording].
  Future<void> startRecording(String path);

  /// Finishes the recording; returns the written file path.
  Future<String?> stopRecording();
}
