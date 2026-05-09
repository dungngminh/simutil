import 'dart:async';
import 'dart:io';

import 'package:nocterm/nocterm.dart';

void recoverTerminalState() {
  writeTerminalRecoverySequences(stdout);
  unawaited(stdout.flush());
}

void writeTerminalRecoverySequences(StringSink sink) {
  sink.write(EscapeCodes.disable.bracketedPasteMode);
  sink.write(EscapeCodes.disable.motionTracking);
  sink.write(EscapeCodes.disable.sgrMouseMode);
  sink.write(EscapeCodes.disable.buttonEventTracking);
  sink.write(EscapeCodes.disable.basicMouseTracking);
  sink.write(EscapeCodes.disable.kittyKeyboard);
  sink.write(EscapeCodes.disable.modifyOtherKeys);
  sink.write(EscapeCodes.showCursor);
  sink.write('\n');
}
