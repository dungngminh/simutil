import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_app/src/stream/device_keyboard.dart';

class _Scrcpy implements ScrcpySession {
  final sent = <Object>[];

  @override
  void typeText(String text) => sent.add(text);

  @override
  void pressKey(int keycode, {int metaState = 0}) => sent.add(keycode);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Emulator implements EmulatorGrpcSession {
  final sent = <String>[];

  @override
  void typeText(String text) => sent.add(text);

  @override
  void pressKey(String key) => sent.add('<$key>');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

KeyEvent _down(LogicalKeyboardKey key, {String? character}) => KeyDownEvent(
  physicalKey: PhysicalKeyboardKey.keyA,
  logicalKey: key,
  character: character,
  timeStamp: Duration.zero,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android: text as text, special keys as key codes, key-ups ignored', () {
    final s = _Scrcpy();
    expect(
      sendKeyToDevice(s, _down(LogicalKeyboardKey.keyA, character: 'a')),
      isTrue,
    );
    expect(sendKeyToDevice(s, _down(LogicalKeyboardKey.backspace)), isTrue);
    // macOS reports arrows with an AppKit function-key character.
    expect(
      sendKeyToDevice(s, _down(LogicalKeyboardKey.arrowLeft, character: '')),
      isTrue,
    );
    expect(
      sendKeyToDevice(
        s,
        const KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.keyA,
          logicalKey: LogicalKeyboardKey.keyA,
          timeStamp: Duration.zero,
        ),
      ),
      isFalse,
    );
    expect(sendKeyToDevice(s, _down(LogicalKeyboardKey.shiftLeft)), isFalse);
    expect(s.sent, ['a', 67, 21]);
  });

  test('Android emulator: text as text, special keys as W3C key values', () {
    final s = _Emulator();
    sendKeyToDevice(s, _down(LogicalKeyboardKey.keyA, character: 'a'));
    sendKeyToDevice(s, _down(LogicalKeyboardKey.enter));
    sendKeyToDevice(s, _down(LogicalKeyboardKey.arrowUp, character: ''));
    expect(s.sent, ['a', '<Enter>', '<ArrowUp>']);
  });
}
