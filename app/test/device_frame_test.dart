import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/devices/device_form_factor.dart';
import 'package:simutil_app/src/ui/shared/device_frame.dart';
import 'package:simutil_core/simutil_core.dart';

Widget _frame(DeviceFormFactor formFactor, List<DeviceButton> pressed) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 400,
          child: DeviceFrame(
            formFactor: formFactor,
            screenSize: const Size(1080, 2400),
            maxHeight: 580,
            enabled: true,
            onButton: pressed.add,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

void main() {
  testWidgets('phone side buttons press power and volume', (tester) async {
    final pressed = <DeviceButton>[];
    await tester.pumpWidget(_frame(DeviceFormFactor.phone, pressed));

    await tester.tap(find.bySemanticsLabel('Power'));
    await tester.tap(find.bySemanticsLabel('Volume up'));
    await tester.tap(find.bySemanticsLabel('Volume down'));

    expect(pressed, [
      DeviceButton.lock,
      DeviceButton.volumeUp,
      DeviceButton.volumeDown,
    ]);
  });

  testWidgets('TVs get no side buttons', (tester) async {
    await tester.pumpWidget(_frame(DeviceFormFactor.tv, []));
    expect(find.bySemanticsLabel('Power'), findsNothing);
  });
}
