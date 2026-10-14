import 'package:flutter/widgets.dart';
import 'package:simutil_app/src/ui/design/design.dart';

/// Common Maestro flow commands, highlighted as keywords in the editor.
const maestroCommands = {
  'launchApp',
  'stopApp',
  'killApp',
  'clearState',
  'clearKeychain',
  'tapOn',
  'doubleTapOn',
  'longPressOn',
  'assertVisible',
  'assertNotVisible',
  'assertTrue',
  'inputText',
  'inputRandomText',
  'inputRandomEmail',
  'eraseText',
  'copyTextFrom',
  'pasteText',
  'swipe',
  'scroll',
  'scrollUntilVisible',
  'back',
  'hideKeyboard',
  'pressKey',
  'openLink',
  'takeScreenshot',
  'waitForAnimationToEnd',
  'extendedWaitUntil',
  'repeat',
  'retry',
  'runFlow',
  'runScript',
  'setLocation',
  'addMedia',
  'startRecording',
  'stopRecording',
  'appId',
};

/// Maestro flow YAML with syntax colors: commands, other keys, strings,
/// numbers and booleans, punctuation, comments.
/// ponytail: colors the whole text each build, no IME composing underline;
/// fine for flow-sized ASCII YAML.
class ScenarioSyntaxController extends TextEditingController {
  ScenarioSyntaxController({super.text});

  static final _token = RegExp(
    r'''("(?:[^"\\]|\\.)*"?|'[^']*'?)|(#.*$)|(^\s*-(?=\s|$))|([A-Za-z_]\w*(?=:(?:\s|$)))|(-?\b\d+(?:\.\d+)?\b)|(\b(?:true|false|null)\b)|([\[\]{},:])''',
    multiLine: true,
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final t = SimuTokens.of(context);
    final spans = <TextSpan>[];
    var at = 0;
    for (final m in _token.allMatches(text)) {
      if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
      final color = switch (m) {
        _ when m[1] != null => t.success,
        _ when m[2] != null => t.textFaint,
        _ when m[3] != null => t.textMuted,
        _ when m[4] != null =>
          maestroCommands.contains(m[4]) ? t.accent : t.warning,
        _ when m[5] != null || m[6] != null => t.apple,
        _ => t.textMuted,
      };
      spans.add(
        TextSpan(
          text: m[0],
          style: TextStyle(
            color: color,
            fontWeight: m[4] != null && maestroCommands.contains(m[4])
                ? FontWeight.w600
                : null,
          ),
        ),
      );
      at = m.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: spans);
  }
}
