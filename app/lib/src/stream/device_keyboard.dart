import 'dart:async';

import 'package:flutter/services.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_app/src/stream/ios/ios_sim_session.dart';
import 'package:simutil_core/simutil_core.dart';

/// Non-printing keys: Android `AKEYCODE_*`, the character the iOS
/// simulator plugin types for it (AppKit function-key characters) and the
/// W3C key value the Android emulator's gRPC API takes.
final _keys = <LogicalKeyboardKey, (int, String, String)>{
  LogicalKeyboardKey.enter: (66, '\n', 'Enter'),
  LogicalKeyboardKey.numpadEnter: (66, '\n', 'Enter'),
  LogicalKeyboardKey.backspace: (67, '\b', 'Backspace'),
  LogicalKeyboardKey.delete: (112, '', 'Delete'),
  LogicalKeyboardKey.tab: (61, '\t', 'Tab'),
  LogicalKeyboardKey.escape: (111, '\x1b', 'Escape'),
  LogicalKeyboardKey.arrowUp: (19, '', 'ArrowUp'),
  LogicalKeyboardKey.arrowDown: (20, '', 'ArrowDown'),
  LogicalKeyboardKey.arrowLeft: (21, '', 'ArrowLeft'),
  LogicalKeyboardKey.arrowRight: (22, '', 'ArrowRight'),
  LogicalKeyboardKey.home: (122, '', 'Home'),
  LogicalKeyboardKey.end: (123, '', 'End'),
  LogicalKeyboardKey.pageUp: (92, '', 'PageUp'),
  LogicalKeyboardKey.pageDown: (93, '', 'PageDown'),
};

/// Forwards a host key press to [session]: special keys as key codes,
/// anything printable as text. Returns false for keys left to the app
/// (shortcuts with Cmd / Ctrl / Alt, key-ups, modifiers alone).
/// ponytail: no Ctrl/Cmd combos (copy, select all); add with meta states.
bool sendKeyToDevice(DeviceSession session, KeyEvent event) {
  if (event is KeyUpEvent) return false;
  final keyboard = HardwareKeyboard.instance;
  if (keyboard.isMetaPressed ||
      keyboard.isControlPressed ||
      keyboard.isAltPressed) {
    return false;
  }
  final special = _keys[event.logicalKey];
  final text = special == null ? _printable(event.character) : null;
  if (special == null && text == null) return false;
  switch (session) {
    case final ScrcpySession s:
      special != null ? s.pressKey(special.$1) : s.typeText(text!);
    case final EmulatorGrpcSession s:
      special != null ? s.pressKey(special.$3) : s.typeText(text!);
    case final IosSimSession s:
      unawaited(s.typeText(special?.$2 ?? text!));
    default:
      return false;
  }
  return true;
}

/// [character] when it types something: not a control character nor an
/// AppKit function-key character (macOS reports arrows as U+F700…).
String? _printable(String? character) {
  if (character == null || character.isEmpty) return null;
  final c = character.codeUnitAt(0);
  if (c < 0x20 || c == 0x7f || (c >= 0xF700 && c <= 0xF8FF)) return null;
  return character;
}
