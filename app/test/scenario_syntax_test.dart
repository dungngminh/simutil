import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_app/src/ui/scenarios/scenario_syntax.dart';

void main() {
  testWidgets('commands, other keys, strings, numbers and comments get colors', (
    tester,
  ) async {
    late TextSpan span;
    late SimuTokens t;
    final controller = ScenarioSyntaxController(
      text: '- tapOn: "Sign # in"  # go\n    direction: 3\n',
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
    expect(colorOf('tapOn'), t.accent);
    expect(colorOf('direction'), t.warning);
    expect(colorOf('"Sign # in"'), t.success); // # in a string is no comment
    expect(colorOf('3'), t.apple);
    expect(colorOf('# go'), t.textFaint);
    expect(span.toPlainText(), controller.text);
  });
}
