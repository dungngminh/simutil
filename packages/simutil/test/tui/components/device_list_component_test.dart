import 'package:nocterm/nocterm.dart';
import 'package:simutil/src/tui/components/device_list_component.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_core/testing.dart';
import 'package:test/test.dart' hide isEmpty, isNotEmpty;

void main() {
  test('d wipes and shift+d deletes the selected device', () async {
    final wiped = <Device>[];
    final deleted = <Device>[];
    final device = testAndroidEmulator();

    await testNocterm('device list d / D', (tester) async {
      await tester.pumpComponent(
        DeviceListComponent(
          devices: [device],
          focused: true,
          onDeviceWipeRequested: wiped.add,
          onDeviceDeleteRequested: deleted.add,
        ),
      );

      await tester.sendKey(LogicalKey.keyD);
      expect(wiped, [device]);
      expect(deleted, <Device>[]);

      await tester.sendKeyEvent(
        const KeyboardEvent(
          logicalKey: LogicalKey.keyD,
          character: 'D',
          modifiers: ModifierKeys(shift: true),
        ),
      );
      expect(deleted, [device]);
      expect(wiped, hasLength(1));
    });
  });
}
