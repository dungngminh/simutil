import 'package:simutil_adb/src/scrcpy/scrcpy_install.dart';
import 'package:simutil_adb/src/scrcpy/scrcpy_session.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_core/testing.dart';
import 'package:test/test.dart';

void main() {
  test(
    'a failed start reaches status listeners before the stream closes',
    () async {
      final session = ScrcpySession(
        serial: 'emulator-5554',
        adbPath: 'adb',
        install: const ScrcpyInstall(serverPath: 'server', version: '3.0'),
        exec: FakeCommandExec((_, _) => FakeCommandExec.fail('device offline')),
      );
      final statuses = session.statusChanges.toList();

      await session.start();

      expect(await statuses, [
        const SessionConnecting(),
        const SessionFailed('Bad state: adb push failed: device offline'),
      ]);
    },
  );
}
