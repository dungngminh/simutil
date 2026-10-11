import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/scenarios/scenario_suggest.dart';

void main() {
  List<String>? labels(String text, {List<String> devices = const []}) =>
      scenarioSuggestions(
        text,
        text.length,
        devices: devices,
      )?.items.map((i) => i.label).toList();

  test('actions after a dash, filtered by what is typed', () {
    expect(labels('steps:\n  - '), hasLength(6));
    expect(labels('steps:\n  - ta'), ['tap']);
    final s = scenarioSuggestions('steps:\n  - sw', 13)!;
    expect(s.start, 11);
    expect(s.items.single.insert, 'swipe: ');
  });

  test('options on indented lines, keys at the top level', () {
    expect(labels('steps:\n  - tap: a\n    re'), ['repeat']);
    expect(labels('steps:\n  - launch: a\n    cl'), ['clear_state']);
    expect(labels('st'), ['steps']);
    expect(labels('steps:\n  - tap: a\n    '), isNull); // nothing typed yet
  });

  test('buttons after press, streamed devices in the devices list', () {
    expect(labels('steps:\n  - press: vo'), ['volumeUp', 'volumeDown']);
    expect(
      labels('devices: [Pixel 8 Pro, iP', devices: ['iPhone Air', 'Pixel']),
      ['iPhone Air'],
    );
  });

  test('nothing inside comments or once the word is complete', () {
    expect(labels('steps:\n  - tap  # ta'), isNull);
    expect(labels('steps:\n  - tap'), isNull);
  });
}
