import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_app/src/ui/scenarios/scenario_editor.dart';

void main() {
  testWidgets('a YAML mistake shows under the editor, which stays open', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: simuTheme(Brightness.dark),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showScenarioEditor(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('steps:'), findsOneWidget); // the template

    await tester.enterText(find.byType(TextField), 'steps:\n  - tapp: x\n');
    await tester.tap(find.text('Run'));
    await tester.pump();
    expect(find.textContaining('Step 1 needs exactly one of'), findsOneWidget);
    expect(find.text('Run'), findsOneWidget);
  });
}
