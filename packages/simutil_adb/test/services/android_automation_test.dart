import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_core/testing.dart';
import 'package:test/test.dart';

const _dump = '''
<?xml version='1.0' encoding='UTF-8' standalone='yes' ?><hierarchy rotation="0"><node index="0" text="" resource-id="" class="android.widget.FrameLayout" content-desc="" bounds="[0,0][1000,2000]"><node index="0" text="" resource-id="" class="android.view.View" content-desc="month&#10;Tab 2 of 2" bounds="[800,200][900,300]" /><node index="1" text="hello" resource-id="com.app:id/title" class="android.widget.TextView" content-desc="" bounds="[0,400][500,500]" /><node index="2" text="" resource-id="" class="android.view.View" content-desc="" bounds="[0,0][10,10]" /></node></hierarchy>UI hierchary dumped to: /dev/tty
''';

final _pixel = Device.android(
  id: 'serial',
  name: 'Pixel',
  state: DeviceState.booted,
  type: DeviceType.physical,
);

void main() {
  test('parses labelled nodes normalized to the root bounds', () {
    final elements = parseUiautomatorDump(_dump);
    expect(elements.map((e) => e.label), ['month\nTab 2 of 2', 'hello']);
    expect(elements[0].centerX, closeTo(0.85, 1e-9));
    expect(elements[0].centerY, closeTo(0.125, 1e-9));
    expect(elements[1].id, 'com.app:id/title');
  });

  test('findElement prefers exact matches over contains', () {
    final elements = [
      const UiElement(
        label: 'month view',
        left: 0,
        top: 0,
        right: 1,
        bottom: 1,
      ),
      const UiElement(label: 'Month', left: 0, top: 0, right: .5, bottom: .5),
    ];
    expect(findElement(elements, 'month')!.right, .5);
    expect(findElement(elements, 'view')!.label, 'month view');
    expect(findElement(elements, 'year'), isNull);
    expect(findElement(elements, 'month', index: -1)!.right, .5);
    expect(findElement(elements, 'month', index: 1), isNull);
  });

  test('typeText quotes for the device shell and encodes spaces', () async {
    final exec = FakeCommandExec((_, _) => FakeCommandExec.ok());
    await AndroidAutomation(
      exec,
      adbPath: () => 'adb',
    ).typeText(_pixel, "it's me");
    expect(exec.calls.single.arguments, [
      '-s',
      'serial',
      'shell',
      'input',
      'text',
      r"'it'\''s%sme'",
    ]);
  });

  test('launch fails when monkey finds no activity', () async {
    final exec = FakeCommandExec(
      (_, _) => FakeCommandExec.ok('** No activities found to run'),
    );
    await expectLater(
      AndroidAutomation(exec, adbPath: () => 'adb').launch(_pixel, 'x.y'),
      throwsStateError,
    );
  });
}
