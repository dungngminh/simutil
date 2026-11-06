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
      exec: _bootedExec(server.port),
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

  test('reports the server closing the video stream', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final connections = StreamIterator(server);
    final session = ScrcpySession(
      serial: 'emulator-5554',
      adbPath: 'true',
      install: const ScrcpyInstall(serverPath: 'server', version: '3.0'),
      exec: _bootedExec(server.port),
    );
    addTearDown(session.stop);
    final statuses = session.statusChanges.toList();

    final starting = session.start();
    expect(await connections.moveNext(), isTrue);
    final video = connections.current
      ..add([0])
      ..add(_u32(0x68323634))
      ..add([..._u32(0x80000000), ..._u32(720), ..._u32(1280)]);
    expect(await connections.moveNext(), isTrue);
    final control = connections.current;
    await starting;

    await video.close();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    control.destroy();
    await session.stop();

    expect(await statuses, contains(const SessionFailed('Stream ended')));
  });

  test('stop() while waiting for the boot ends the wait and starts no '
      'server', () async {
    final exec = FakeCommandExec(
      (_, args) => args.contains('getprop')
          ? FakeCommandExec.ok('0\n')
          : FakeCommandExec.ok('1234\n'),
    );
    final session = ScrcpySession(
      serial: 'emulator-5554',
      adbPath: 'true',
      install: const ScrcpyInstall(serverPath: 'server', version: '3.0'),
      exec: exec,
    );

    final starting = session.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await session.stop();
    await starting.timeout(const Duration(seconds: 3));

    expect(
      exec.calls.where(
        (c) => c.arguments.contains('push') || c.arguments.contains('forward'),
      ),
      isEmpty,
    );
  });

  test('stop() during the start removes a forward created after it', () async {
    final forwardRequested = Completer<void>();
    final releaseForward = Completer<void>();
    final exec = _GatedExec((args) async {
      if (args.contains('getprop')) return FakeCommandExec.ok('1\n');
      if (args.contains('forward') && !args.contains('--remove')) {
        forwardRequested.complete();
        await releaseForward.future;
        return FakeCommandExec.ok('4321\n');
      }
      return FakeCommandExec.ok();
    });
    final session = ScrcpySession(
      serial: 'emulator-5554',
      adbPath: 'true',
      install: const ScrcpyInstall(serverPath: 'server', version: '3.0'),
      exec: exec,
    );

    final starting = session.start();
    await forwardRequested.future;
    await session.stop();
    releaseForward.complete();
    await starting;

    expect(
      exec.calls,
      contains(
        equals(['-s', 'emulator-5554', 'forward', '--remove', 'tcp:4321']),
      ),
    );
  });
}

/// adb reports the device booted and forwards to [port].
FakeCommandExec _bootedExec(int port) => FakeCommandExec(
  (_, args) => switch (args) {
    _ when args.contains('getprop') => FakeCommandExec.ok('1\n'),
    _ when args.contains('forward') && !args.contains('--remove') =>
      FakeCommandExec.ok('$port\n'),
    _ => FakeCommandExec.ok(),
  },
);

/// A [CommandExec] whose results the test can hold back.
class _GatedExec implements CommandExec {
  _GatedExec(this.handler);

  final Future<CommandResult> Function(List<String> args) handler;
  final calls = <List<String>>[];

  @override
  Future<CommandResult> run(
    String command, {
    List<String> arguments = const [],
    String? workingDirectory,
    Duration? timeout,
    CommandPriority priority = CommandPriority.normal,
  }) {
    calls.add(arguments);
    return handler(arguments);
  }
}

List<int> _u32(int v) =>
    (ByteData(4)..setUint32(0, v)).buffer.asUint8List().toList();

List<int> _u64(int v) =>
    (ByteData(8)..setUint64(0, v)).buffer.asUint8List().toList();
