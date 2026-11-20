import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_app/src/ui/scenarios/scenario_code_editor.dart';

void main() {
  Future<TextEditingController> pumpEditor(WidgetTester tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: simuTheme(Brightness.light),
        home: Scaffold(body: ScenarioCodeEditor(controller: controller)),
      ),
    );
    return controller;
  }

  testWidgets('a key typed at the start of an empty editor is suggested', (
    tester,
  ) async {
    final controller = await pumpEditor(tester);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 's');
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('steps'), findsOneWidget);

    // Clicking the suggestion takes it (on desktop a click outside the
    // field unfocuses it first).
    await tester.tap(find.text('steps'), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(controller.text, startsWith('steps'));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
