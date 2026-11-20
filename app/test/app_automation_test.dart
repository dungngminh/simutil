import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/automation/app_automation.dart';
import 'package:simutil_app/src/stream/ios/ios_sim_session.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_core/testing.dart';

/// Answers accessibility snapshots from [snapshots] in turn (the last one
/// repeats) and records the element it was asked to press.
class _FakeSimSession implements IosSimSession {
  _FakeSimSession(this.snapshots);

  final List<List<UiElement>> snapshots;
  UiElement? pressed;
  var _next = 0;

  @override
  Future<List<UiElement>> accessibilityElements() async =>
      snapshots[_next < snapshots.length - 1 ? _next++ : _next];

  @override
  Future<bool> pressElement(UiElement element) async {
    pressed = element;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoAutomation implements DeviceAutomation {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  UiElement button(int handle, double top, {String label = 'Delete'}) =>
      UiElement(
        label: label,
        role: 'button',
        left: 0.1,
        top: top,
        right: 0.9,
        bottom: top + 0.05,
        handle: handle,
      );

  test('taps the element it was given, not its first namesake', () async {
    final first = button(1, 0.2);
    final second = button(2, 0.6);
    final session = _FakeSimSession([
      [first, second],
    ]);
    final automation = AppAutomation(
      android: _NoAutomation(),
      ios: _NoAutomation(),
      iosSession: (_) => session,
    );

    // A query with index 1 found the second "Delete" button.
    expect(await automation.tapElement(testIosSimulator(), second), isTrue);
    expect(session.pressed?.handle, 2);
  });

  test('an element without label or id keeps its own position', () async {
    final field = button(3, 0.7, label: '');
    final session = _FakeSimSession([
      [button(4, 0.1, label: ''), field],
    ]);
    final automation = AppAutomation(
      android: _NoAutomation(),
      ios: _NoAutomation(),
      iosSession: (_) => session,
    );

    expect(await automation.tapElement(testIosSimulator(), field), isTrue);
    expect(session.pressed?.handle, 3);
  });

  test('look-alikes moving together keep the chosen one', () async {
    // A sheet slides up by 0.4: the second "Delete" ends up where the first
    // one was found, so nearest-position would pick it.
    final found = [button(1, 0.6), button(2, 0.8)];
    final session = _FakeSimSession([
      found,
      [button(3, 0.4), button(4, 0.6)],
      [button(5, 0.2), button(6, 0.4)],
    ]);
    final automation = AppAutomation(
      android: _NoAutomation(),
      ios: _NoAutomation(),
      iosSession: (_) => session,
    );

    final elements = await automation.elements(testIosSimulator());
    expect(
      await automation.tapElement(testIosSimulator(), elements[0]),
      isTrue,
    );
    expect(session.pressed?.handle, 5);
  });
}
