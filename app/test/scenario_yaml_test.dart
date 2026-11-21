import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/scenarios/scenario_yaml.dart';
import 'package:simutil_core/simutil_core.dart';

void main() {
  test('flowStepLines finds top-level commands after the config', () {
    const flow = '''
# comment
appId: x
---
- launchApp
- repeat:
    commands:
      - tapOn: "A"
# - back
- assertVisible: "B"
''';
    expect(flowStepLines(flow), [3, 4, 8]);
  });

  test('every platform has a template', () {
    for (final os in DeviceOs.values) {
      expect(scenarioTemplate(os), contains('appId:'));
    }
  });
}
