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

  test('launch stops the app first, or clears it with clearState', () async {
    final exec = FakeCommandExec(
      (_, args) => FakeCommandExec.ok(args.contains('clear') ? 'Success' : ''),
    );
    final adb = AndroidAutomation(exec, adbPath: () => 'adb');
    await adb.launch(_pixel, 'x.y');
    await adb.launch(_pixel, 'x.y', clearState: true);
    final shells = [
      for (final c in exec.calls) c.arguments.skip(3).take(2).join(' '),
    ];
    expect(shells, ['am force-stop', 'monkey -p', 'pm clear', 'monkey -p']);
  });

  test('clearState fails loudly when pm clear does not succeed', () async {
    final exec = FakeCommandExec(
      (_, args) => args.contains('clear')
          ? FakeCommandExec.ok('Failed')
          : FakeCommandExec.ok(),
    );
    await expectLater(
      AndroidAutomation(
        exec,
        adbPath: () => 'adb',
      ).launch(_pixel, 'x.y', clearState: true),
      throwsStateError,
    );
  });

  test('a dialog dump is normalized to the screen, not its own window', () {
    const dialog = '''
<hierarchy rotation="0"><node index="0" text="" resource-id="" class="android.widget.FrameLayout" content-desc="" bounds="[25,797][982,1506]"><node index="0" text="Allow" resource-id="permission_allow_button" class="android.widget.Button" content-desc="" bounds="[118,1197][915,1286]" /></node></hierarchy>''';
    final allow = parseUiautomatorDump(dialog, screen: (1008, 2244)).single;
    expect(allow.centerX, closeTo(516.5 / 1008, 1e-9));
    expect(allow.centerY, closeTo(1241.5 / 2244, 1e-9));
    // Landscape: the portrait size is swapped.
    final turned = parseUiautomatorDump(
      dialog.replaceFirst('rotation="0"', 'rotation="1"'),
      screen: (1008, 2244),
    ).single;
    expect(turned.centerX, closeTo(516.5 / 2244, 1e-9));
  });

  test('elements read the screen size once per device', () async {
    final exec = FakeCommandExec(
      (_, args) => args.contains('wm')
          ? FakeCommandExec.ok(
              'Physical size: 1080x2400\nOverride size: 1008x2244\n',
            )
          : FakeCommandExec.ok(_dump),
    );
    final adb = AndroidAutomation(exec, adbPath: () => 'adb');
    final first = await adb.elements(_pixel);
    await adb.elements(_pixel);
    expect(exec.calls.where((c) => c.arguments.contains('wm')), hasLength(1));
    expect(first.first.centerX, closeTo(850 / 1008, 1e-9));
  });

  test('tapElement taps the node center in pixels with input tap', () async {
    final exec = FakeCommandExec((_, args) => FakeCommandExec.ok());
    final element = parseUiautomatorDump(_dump, screen: (1000, 2000)).first;
    expect(
      await AndroidAutomation(
        exec,
        adbPath: () => 'adb',
      ).tapElement(_pixel, element),
      isTrue,
    );
    expect(exec.calls.single.arguments, [
      '-s',
      'serial',
      'shell',
      'input',
      'tap',
      '850',
      '250',
    ]);
  });
}
