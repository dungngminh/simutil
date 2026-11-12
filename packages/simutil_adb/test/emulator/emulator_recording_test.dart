import 'dart:async';

import 'package:simutil_adb/src/emulator/emulator_endpoint.dart';
import 'package:simutil_adb/src/emulator/emulator_grpc_session.dart';
import 'package:simutil_core/testing.dart';
import 'package:test/test.dart';

void main() {
  EmulatorGrpcSession session(FakeCommandExec exec) => EmulatorGrpcSession(
    serial: 'emulator-5554',
    // Recording only goes through `adb emu`; no gRPC call is made.
    endpoint: const EmulatorEndpoint(port: 1),
    adbPath: 'adb',
    exec: exec,
  );

  bool isStop(List<String> args) =>
      args.contains('screenrecord') && args.contains('stop');

  for (final (name, stop) in [
    ('times out', () => throw TimeoutException('hung console')),
    ('reports KO', () => FakeCommandExec.ok('KO: not recording\n')),
    ('fails', () => FakeCommandExec.fail('error: device offline')),
  ]) {
    test('nothing is saved when screenrecord stop $name', () async {
      final exec = FakeCommandExec(
        (_, args) => isStop(args) ? stop() : FakeCommandExec.ok('OK\n'),
      );
      final s = session(exec);
      await s.startRecording('/tmp/simutil-test.mp4');

      expect(await s.stopRecording(), isNull);
      expect(s.isRecording, isFalse);
      // No conversion of a file the emulator may still be writing.
      expect(exec.calls.where((c) => c.command.endsWith('ffmpeg')), isEmpty);
    });
  }
}
