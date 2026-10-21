import 'package:simutil_adb/src/emulator/generated/emulator_controller.pb.dart';
import 'package:simutil_core/simutil_core.dart';

/// Builds the emulator gRPC `InputEvent`s for [DeviceSession] input.
abstract final class EmulatorInput {
  /// Emulator `Touch.pressure` while down; zero lifts the finger.
  static const pressure = 0x400;

  /// A one-finger touch at ([x], [y]) (0..1 of the screen as shown, rotated
  /// by [rotation]) on a display of [width]x[height] pixels in its natural
  /// (unrotated) orientation, where the emulator takes touch coordinates.
  static InputEvent touch(
    TouchPhase phase,
    double x,
    double y, {
    required int width,
    required int height,
    Rotation_SkinRotation rotation = Rotation_SkinRotation.PORTRAIT,
  }) {
    final (u, v) = (x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
    final (nx, ny) = switch (rotation) {
      Rotation_SkinRotation.LANDSCAPE => (1 - v, u),
      Rotation_SkinRotation.REVERSE_PORTRAIT => (1 - u, 1 - v),
      Rotation_SkinRotation.REVERSE_LANDSCAPE => (v, 1 - u),
      _ => (u, v),
    };
    return InputEvent(
      touchEvent: TouchEvent(
        touches: [
          Touch(
            x: (nx * (width - 1)).round(),
            y: (ny * (height - 1)).round(),
            pressure: phase == TouchPhase.up ? 0 : pressure,
          ),
        ],
      ),
    );
  }

  /// A W3C `KeyboardEvent.key` value ([key]), pressed and released.
  static InputEvent key(String key) => InputEvent(
    keyEvent: KeyboardEvent(
      eventType: KeyboardEvent_KeyEventType.keypress,
      key: key,
    ),
  );

  /// Types [text]; the emulator drops characters outside printable ASCII.
  static InputEvent text(String text) =>
      InputEvent(keyEvent: KeyboardEvent(text: text));

  /// The [key] value the emulator maps to [button].
  static String buttonKey(DeviceButton button) => switch (button) {
    DeviceButton.back => 'GoBack',
    DeviceButton.home => 'GoHome',
    DeviceButton.recents => 'AppSwitch',
    DeviceButton.lock => 'Power',
    DeviceButton.volumeUp => 'AudioVolumeUp',
    DeviceButton.volumeDown => 'AudioVolumeDown',
  };
}
