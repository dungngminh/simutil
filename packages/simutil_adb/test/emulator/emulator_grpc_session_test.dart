import 'dart:async';

import 'package:grpc/grpc.dart';
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart';
import 'package:simutil_adb/src/emulator/emulator_endpoint.dart';
import 'package:simutil_adb/src/emulator/emulator_grpc_session.dart';
import 'package:simutil_adb/src/emulator/generated/emulator_controller.pbgrpc.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_core/testing.dart';
import 'package:test/test.dart';

/// An emulator whose display answers [screenshot] in turn.
class _FakeEmulator extends EmulatorControllerServiceBase {
  _FakeEmulator(this.screenshot);

  final Future<Image> Function(int call) screenshot;
  var calls = 0;

  @override
  Future<Image> getScreenshot(ServiceCall call, ImageFormat request) =>
      screenshot(++calls);

  @override
  Stream<Image> streamScreenshot(ServiceCall call, ImageFormat request) =>
      const Stream.empty();

  @override
  Future<Empty> streamInputEvent(
    ServiceCall call,
    Stream<InputEvent> request,
  ) async {
    await request.drain<void>();
    return Empty();
  }
}

Image _display(int width, int height) => Image(
  format: ImageFormat(width: width, height: height),
);

void main() {
  late Server server;

  Future<EmulatorGrpcSession> sessionFor(_FakeEmulator emulator) async {
    server = Server.create(services: [emulator]);
    await server.serve(port: 0);
    addTearDown(server.shutdown);
    return EmulatorGrpcSession(
      serial: 'emulator-5554',
      endpoint: EmulatorEndpoint(port: server.port!),
      adbPath: 'adb',
      exec: FakeCommandExec((_, _) => FakeCommandExec.ok()),
    );
  }

  test('waits while the guest has not posted a frame yet', () async {
    final emulator = _FakeEmulator(
      (call) async => call <= 2
          ? throw const GrpcError.unavailable(
              'The guest has not posted new frames',
            )
          : call == 3
          ? _display(0, 0)
          : _display(1080, 2424),
    );
    final session = await sessionFor(emulator);
    addTearDown(session.stop);

    await session.start();

    expect(session.status, const SessionLive(width: 1080, height: 2424));
    expect(emulator.calls, 4);
  });

  test('fails at once on errors waiting cannot fix', () async {
    final emulator = _FakeEmulator(
      (_) async => throw const GrpcError.unauthenticated('bad token'),
    );
    final session = await sessionFor(emulator);
    final statuses = session.statusChanges.toList();

    await session.start();

    expect(await statuses, [
      const SessionConnecting(),
      const SessionFailed('gRPC: bad token'),
    ]);
    expect(emulator.calls, 1);
  });
}
