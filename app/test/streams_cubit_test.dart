import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_core/simutil_core.dart';

class _FakeSession implements DeviceSession {
  _FakeSession(this.deviceId);

  @override
  final String deviceId;
  bool stopped = false;

  @override
  Future<void> stop() async => stopped = true;

  @override
  Future<void> start() async {}

  @override
  Stream<SessionStatus> get statusChanges => const Stream.empty();

  @override
  SessionStatus get status => const SessionConnecting();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Device sim(DeviceState state) => Device.ios(
    id: 'UDID',
    name: 'iPhone',
    state: state,
    type: DeviceType.simulator,
  );

  test(
    'closes a stream once its device stays shut down past the grace',
    () async {
      final session = _FakeSession('UDID');
      final cubit = StreamsCubit((_) async => session);
      await cubit.open(sim(DeviceState.booted));
      final t0 = DateTime(2026);

      cubit.onDevices([sim(DeviceState.shutdown)], now: t0);
      expect(cubit.stateValue.isOpen('UDID'), isTrue);

      cubit.onDevices([
        sim(DeviceState.booted),
      ], now: t0.add(const Duration(seconds: 10)));
      cubit.onDevices([], now: t0.add(const Duration(seconds: 20)));
      expect(
        cubit.stateValue.isOpen('UDID'),
        isTrue,
        reason: 'grace restarts after it came back',
      );

      cubit.onDevices([], now: t0.add(const Duration(seconds: 36)));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.stateValue.isOpen('UDID'), isFalse);
      expect(session.stopped, isTrue);
    },
  );
}
