import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
        const SessionFailed(
          'Bad state: device did not finish booting: device offline',
        ),
      ]);
    },
  );

  test('goes live with the control socket and streams config-prefixed key '
      'frames from the video worker', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final connections = StreamIterator(server);
    final session = ScrcpySession(
      serial: 'emulator-5554',
      // Process.start target for the server; `true` exits at once.
      adbPath: 'true',
      install: const ScrcpyInstall(serverPath: 'server', version: '3.0'),
      exec: FakeCommandExec(
        (_, args) => args.contains('forward') && !args.contains('--remove')
            ? FakeCommandExec.ok('${server.port}\n')
            : FakeCommandExec.ok(),
      ),
    );
    addTearDown(session.stop);
    final live = session.statusChanges.firstWhere((s) => s is SessionLive);

    final starting = session.start();
    expect(await connections.moveNext(), isTrue);
    final video = connections.current;
    final config = [0, 0, 0, 1, 0x67, 0, 0, 0, 1, 0x68];
    final idr = [0, 0, 0, 1, 0x65, 1, 2, 3];
    video
      ..add([0]) // dummy byte
      ..add(_u32(0x68323634)) // codec id: h264
      ..add([..._u32(0x80000000), ..._u32(720), ..._u32(1280)])
      ..add([..._u64(1 << 62), ..._u32(config.length), ...config])
      ..add([..._u64((1 << 61) | 16000), ..._u32(idr.length), ...idr]);
    expect(await connections.moveNext(), isTrue);
    final control = connections.current;
    final controlBytes = <int>[];
    control.listen(controlBytes.addAll);
    await starting;

    expect(await live, const SessionLive(width: 720, height: 1280));

    final frame = session.video.first;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // Subscribing asks for a fresh key frame (RESET_VIDEO = 17).
    expect(controlBytes, [17]);
    video.add([..._u64((1 << 61) | 32000), ..._u32(idr.length), ...idr]);
    expect(await frame, Uint8List.fromList([...config, ...idr]));
    video.destroy();
    control.destroy();
  });
}

List<int> _u32(int v) =>
    (ByteData(4)..setUint32(0, v)).buffer.asUint8List().toList();

List<int> _u64(int v) =>
    (ByteData(8)..setUint64(0, v)).buffer.asUint8List().toList();
