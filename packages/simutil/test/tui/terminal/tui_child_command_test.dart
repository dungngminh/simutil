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
        script: snapshot,
        executable: dart,
        executableArguments: vmFlags,
      ),
      dart,
      [...vmFlags, snapshot],
    );
  });

  test('restarts a compiled executable as is', () {
    expectCommand(
      tuiChildCommand(
        script: '/usr/local/bin/simutil',
        executable: '/usr/local/bin/simutil',
        executableArguments: const [],
      ),
      '/proc/self/exe',
      const [],
    );
  });
}
