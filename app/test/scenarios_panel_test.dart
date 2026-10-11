import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_app/src/scenarios/scenario_runs_cubit.dart';
import 'package:simutil_app/src/scenarios/scenario_yaml.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_app/src/ui/scenarios/scenarios_panel.dart';

void main() {
  late ScenarioRunsCubit runs;

  setUp(() => runs = ScenarioRunsCubit());
  tearDown(() => runs.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      BlocSignalProvider<ScenarioRunsCubit>.value(
        value: runs,
        child: MaterialApp(
          theme: simuTheme(Brightness.dark),
          home: Scaffold(body: ScenariosPanel(onClose: () {})),
        ),
      ),
    );
  }

  const source = 'steps:\n  - tap: month\n  - tap: Previous\n  - wait: 10\n';

  int start() => runs.start(
    {'a': 'iPhone', 'b': 'Pixel'},
    ['tap "month"', 'tap "Previous"', 'wait 10 ms'],
    source: source,
    lines: stepLines(source),
  );

  testWidgets('an agent run shows as YAML with step status in the gutter', (
    tester,
  ) async {
    await pump(tester);
    final id = start();
    runs
      ..progress(id, 'a', 1)
      ..progress(id, 'b', 1);
    await tester.pump(); // follow the run
    await tester.pump(); // its text lands after the frame
    expect(find.textContaining('tap: Previous'), findsOneWidget);
    expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget); // step 1
    expect(find.byType(SimuSpinner), findsWidgets); // step 2 and the run
    expect(find.byIcon(LucideIcons.circle), findsOneWidget); // step 3
    expect(find.text('Running…'), findsOneWidget);
  });

  testWidgets('a failed step shows its line and each device error', (
    tester,
  ) async {
    await pump(tester);
    final id = start();
    runs
      ..progress(id, 'a', 1)
      ..finish(id, 'a', ms: 900, error: 'No element "Previous"')
      ..progress(id, 'b', 3)
      ..finish(id, 'b', ms: 1200);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Line 3 · tap "Previous"'), findsOneWidget);
    expect(
      find.textContaining('iPhone: No element "Previous"'),
      findsOneWidget,
    );
    expect(find.text('Run'), findsOneWidget);
  });

  testWidgets('a YAML mistake shows under the editor', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'steps:\n  - tapp: x\n');
    await tester.tap(find.text('Run'));
    await tester.pump();
    expect(find.textContaining('Step 1 needs exactly one of'), findsOneWidget);
  });
}
