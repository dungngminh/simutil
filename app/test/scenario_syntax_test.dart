import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_app/src/ui/scenarios/scenario_syntax.dart';

void main() {
  testWidgets('actions, options, strings, numbers and comments get colors', (
    tester,
  ) async {
    late TextSpan span;
    late SimuTokens t;
    final controller = ScenarioSyntaxController(
      text: 'steps:\n  - tap: "Sign in"  # go\n    repeat: 3\n',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: simuTheme(Brightness.dark),
        home: Builder(
          builder: (context) {
            t = SimuTokens.of(context);
            span = controller.buildTextSpan(
              context: context,
              withComposing: false,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    Color? colorOf(String text) => span.children!
        .cast<TextSpan>()
        .firstWhere((s) => s.text == text)
        .style
        ?.color;
    expect(colorOf('tap'), t.accent);
    expect(colorOf('repeat'), t.warning);
    expect(colorOf('"Sign in"'), t.success);
    expect(colorOf('3'), t.apple);
    expect(colorOf('# go'), t.textFaint);
    expect(span.toPlainText(), controller.text);
  });
}
