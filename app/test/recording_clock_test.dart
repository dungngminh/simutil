import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_app/src/ui/shared/recording_clock.dart';

void main() {
  test('formats elapsed time as HH:MM:SS', () {
    expect(formatRecordingTime(Duration.zero), '00:00:00');
    expect(formatRecordingTime(const Duration(seconds: 59)), '00:00:59');
    expect(
      formatRecordingTime(const Duration(minutes: 1, seconds: 23)),
      '00:01:23',
    );
    expect(
      formatRecordingTime(const Duration(hours: 12, minutes: 5, seconds: 9)),
      '12:05:09',
    );
    expect(formatRecordingTime(const Duration(seconds: -3)), '00:00:00');
  });

  testWidgets('ticks every second while mounted', (tester) async {
    var elapsed = const Duration(seconds: 59);
    await tester.pumpWidget(
      MaterialApp(
        theme: simuTheme(Brightness.dark),
        home: RecordingClock(elapsed: () => elapsed),
      ),
    );
    expect(find.text('REC 00:00:59'), findsOneWidget);

    elapsed = const Duration(hours: 1, seconds: 1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('REC 01:00:01'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
