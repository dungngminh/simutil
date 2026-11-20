import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/ui/shared/touch_surface.dart';
import 'package:simutil_core/simutil_core.dart';

class _Session implements DeviceSession {
  final touches = <TouchPhase>[];

  @override
  String get deviceId => 'dev';

  @override
  void touch(TouchPhase phase, double x, double y) => touches.add(phase);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<_Session> pump(WidgetTester tester) async {
    final session = _Session();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 200,
            height: 400,
            child: TouchSurface(session: session),
          ),
        ),
      ),
    );
    return session;
  }

  testWidgets('a right click is not a tap on the device', (tester) async {
    final session = await pump(tester);
    final center = tester.getCenter(find.byType(TouchSurface));

    final right = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    await right.up();
    expect(session.touches, isEmpty);

    await tester.tapAt(center, kind: PointerDeviceKind.mouse);
    expect(session.touches, [TouchPhase.down, TouchPhase.up]);
  });

  testWidgets('a cancelled pointer lifts the finger', (tester) async {
    final session = await pump(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TouchSurface)),
    );
    await gesture.cancel();
    expect(session.touches, [TouchPhase.down, TouchPhase.up]);
  });
}
