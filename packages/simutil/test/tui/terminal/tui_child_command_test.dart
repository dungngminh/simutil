import 'package:simutil/src/tui/terminal/tui_supervisor.dart';
import 'package:test/test.dart';

void main() {
  const dart = '/usr/lib/dart/bin/dart';
  const vmFlags = ['--executable_name=dart'];

  void expectCommand(
    (String, List<String>) actual,
    String command,
    List<String> arguments,
  ) {
    expect(actual.$1, command);
    expect(actual.$2, arguments);
  }

  test('reruns a .dart script with the VM', () {
    expectCommand(
      tuiChildCommand(
        compiled: false,
        script: '/src/bin/simutil.dart',
        executable: dart,
        executableArguments: vmFlags,
      ),
      dart,
      [...vmFlags, '/src/bin/simutil.dart'],
    );
  });

  test('reruns the snapshot of `dart pub global run` with the VM', () {
    const snapshot =
        '/pkg/.dart_tool/pub/bin/simutil/simutil.dart-3.13.7.snapshot';
    expectCommand(
      tuiChildCommand(
        compiled: false,
        script: snapshot,
        executable: dart,
        executableArguments: vmFlags,
      ),
      dart,
      [...vmFlags, snapshot],
    );
  });

  test('restarts a compiled executable as is, also via a symlink', () {
    // Via a symlink or PATH, script is not the resolved executable.
    for (final script in ['/usr/local/bin/simutil', '/simutil']) {
      expectCommand(
        tuiChildCommand(
          compiled: true,
          script: script,
          executable: '/opt/simutil/simutil',
          executableArguments: const [],
        ),
        '/proc/self/exe',
        const [],
      );
    }
  });
}
