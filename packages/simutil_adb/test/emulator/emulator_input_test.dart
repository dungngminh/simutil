import 'package:simutil_adb/src/emulator/emulator_input.dart';
import 'package:simutil_adb/src/emulator/generated/emulator_controller.pb.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:test/test.dart';

void main() {
  Touch touch(
    TouchPhase phase,
    double x,
    double y, [
    Rotation_SkinRotation rotation = Rotation_SkinRotation.PORTRAIT,
  ]) => EmulatorInput.touch(
    phase,
    x,
    y,
    width: 1001,
    height: 2001,
    rotation: rotation,
  ).touchEvent.touches.single;

  test('touch maps to display pixels with pressure until up', () {
    final down = touch(TouchPhase.down, 0.25, 0.75);
    expect(
      (down.x, down.y, down.pressure),
      (250, 1500, EmulatorInput.pressure),
    );
    expect(touch(TouchPhase.move, 0.5, 0.5).pressure, EmulatorInput.pressure);
    expect(touch(TouchPhase.up, 0.5, 0.5).pressure, 0);
    final clamped = touch(TouchPhase.down, -1, 2);
    expect((clamped.x, clamped.y), (0, 2000));
  });

  // Checked on an emulator with pointer_location: (0.25, 0.75) of the
  // rotated frame lands there in every rotation.
  test('touch undoes the screen rotation', () {
    Touch at(Rotation_SkinRotation r) => touch(TouchPhase.down, 0.25, 0.75, r);
    final landscape = at(Rotation_SkinRotation.LANDSCAPE);
    expect((landscape.x, landscape.y), (250, 500));
    final reversePortrait = at(Rotation_SkinRotation.REVERSE_PORTRAIT);
    expect((reversePortrait.x, reversePortrait.y), (750, 500));
    final reverseLandscape = at(Rotation_SkinRotation.REVERSE_LANDSCAPE);
    expect((reverseLandscape.x, reverseLandscape.y), (750, 1500));
  });

  test('buttons and keys are W3C key presses', () {
    final home = EmulatorInput.key(
      EmulatorInput.buttonKey(DeviceButton.home),
    ).keyEvent;
    expect(home.key, 'GoHome');
    expect(home.eventType, KeyboardEvent_KeyEventType.keypress);
    expect(DeviceButton.values.map(EmulatorInput.buttonKey), [
      'GoBack',
      'GoHome',
      'AppSwitch',
      'Power',
      'AudioVolumeUp',
      'AudioVolumeDown',
    ]);
  });

  test('text goes in KeyboardEvent.text', () {
    expect(EmulatorInput.text('hi there').keyEvent.text, 'hi there');
  });
}
