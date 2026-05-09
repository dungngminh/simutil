import 'package:nocterm/nocterm.dart';
import 'package:simutil/utils/terminal_cleanup.dart';
import 'package:test/test.dart';

void main() {
  group('writeTerminalRecoverySequences', () {
    test('writes escape sequences needed to restore terminal input state', () {
      final buffer = StringBuffer();

      writeTerminalRecoverySequences(buffer);
      final output = buffer.toString();

      expect(output, contains(EscapeCodes.disable.bracketedPasteMode));
      expect(output, contains(EscapeCodes.disable.motionTracking));
      expect(output, contains(EscapeCodes.disable.sgrMouseMode));
      expect(output, contains(EscapeCodes.disable.buttonEventTracking));
      expect(output, contains(EscapeCodes.disable.basicMouseTracking));
      expect(output, contains(EscapeCodes.disable.kittyKeyboard));
      expect(output, contains(EscapeCodes.disable.modifyOtherKeys));
      expect(output, contains(EscapeCodes.showCursor));
      expect(output.endsWith('\n'), isTrue);
    });
  });
}
