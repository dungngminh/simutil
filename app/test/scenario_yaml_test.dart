import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/scenarios/scenario_yaml.dart';

void main() {
  test('shorthand steps become run_scenario steps', () {
    final args = scenarioFromYaml('''
devices: [iPhone 17 Pro]
steps:
  - launch: me.komkatstudio.loggoo
  - tap: month
  - tap: [0.5, 0.8]
  - tap: 15
  - swipe: "11"
    dy: -0.08
    until: "15"
  - swipe: [0.5, 0.8, 0.5, 0.3]
  - type: Hello loggoo
  - press: back
  - wait: 500
  - tap: Previous
    repeat: 4
  - launch: {android: a.b, ios: c.d}
  - action: tap
    x: 0.1
    y: 0.2
''');
    expect(args['devices'], ['iPhone 17 Pro']);
    expect(args['steps'], [
      {'action': 'launch', 'app': 'me.komkatstudio.loggoo'},
      {'action': 'tap', 'label': 'month'},
      {'action': 'tap', 'x': 0.5, 'y': 0.8},
      {'action': 'tap', 'label': '15'},
      {'action': 'swipe', 'dy': -0.08, 'until': '15', 'label': '11'},
      {'action': 'swipe', 'x1': 0.5, 'y1': 0.8, 'x2': 0.5, 'y2': 0.3},
      {'action': 'type', 'text': 'Hello loggoo'},
      {'action': 'press', 'button': 'back'},
      {'action': 'wait', 'ms': 500},
      {'action': 'tap', 'repeat': 4, 'label': 'Previous'},
      {'action': 'launch', 'android': 'a.b', 'ios': 'c.d'},
      {'action': 'tap', 'x': 0.1, 'y': 0.2},
    ]);
  });

  test('the template parses', () {
    expect(scenarioFromYaml(scenarioTemplate)['steps'], hasLength(11));
  });

  test('mistakes are reported with the step number', () {
    expect(
      () => scenarioFromYaml('steps:\n  - tap: a\n  - tapp: b\n'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Step 2'),
        ),
      ),
    );
    expect(() => scenarioFromYaml('steps: ['), throwsFormatException);
    expect(() => scenarioFromYaml('steps: []'), throwsFormatException);
  });

  test('agent steps round-trip through YAML, with each step line', () {
    final args = {
      'devices': ['Pixel 8 Pro'],
      'steps': [
        {'action': 'launch', 'android': 'a.b', 'ios': 'c.d'},
        {'action': 'tap', 'label': 'month', 'index': -1},
        {'action': 'tap', 'label': '15'},
        {'action': 'tap', 'x': 0.5, 'y': 0.25},
        {'action': 'swipe', 'label': 'a: b', 'dy': -0.1, 'until': 'true'},
        {'action': 'type', 'text': 'Hello # world'},
        {'action': 'wait', 'ms': 300, 'repeat': 2},
      ],
    };
    final yaml = scenarioToYaml(args);
    expect(scenarioFromYaml(yaml), args);
    expect(stepLines(yaml), [2, 3, 5, 6, 7, 10, 11]);
    expect(stepLines('steps: ['), isEmpty);
  });
}
