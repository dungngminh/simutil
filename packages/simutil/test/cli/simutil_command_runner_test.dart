import 'package:simutil/simutil.dart';
import 'package:test/test.dart';

void main() {
  test('SimutilCommandRunner registers core subcommands', () {
    final runner = SimutilCommandRunner(version: '1.0.0');
    final names = runner.commands.keys.toList();

    expect(
      names,
      containsAll([
        'android',
        'ios',
        'list',
        'launch',
        'shutdown',
        'plugin',
        'schema',
        'upgrade',
        'version',
      ]),
    );
  });

  test('simutilCliSchema includes android emulator list for agents', () {
    final schema = simutilCliSchema(version: '1.0.0');
    final commands = schema['commands'] as List<dynamic>;
    final android =
        commands.firstWhere((entry) => (entry as Map)['name'] == 'android')
            as Map<String, dynamic>;
    final emulator =
        (android['subcommands'] as List).firstWhere(
              (entry) => (entry as Map)['name'] == 'emulator',
            )
            as Map<String, dynamic>;
    final list =
        (emulator['subcommands'] as List).first as Map<String, dynamic>;

    expect(list['usage'], 'simutil android emulator list [options]');
    expect(list['examples'], isNotEmpty);
  });

  test('formatCliTable aligns columns', () {
    final table = formatCliTable(
      columns: const [
        CliTableColumn('NAME', minWidth: 8),
        CliTableColumn('STATE', minWidth: 8),
      ],
      rows: const [
        ['Pixel_7_Pro_big_Android_15', 'Shutdown'],
        ['Pixel_4_Android_10', 'Shutdown'],
      ],
    );

    expect(table, contains('Pixel_7_Pro_big_Android_15'));
    expect(table, contains('─'));
  });
}
