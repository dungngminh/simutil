import 'package:simutil_cli/simutil_cli.dart';
import 'package:test/test.dart';

void main() {
  test('SimutilCommandRunner registers core subcommands', () {
    final runner = SimutilCommandRunner(version: '1.0.0');
    final names = runner.commands.keys.toList();

    expect(names, containsAll(['list', 'launch', 'shutdown', 'plugin', 'version']));
  });
}
