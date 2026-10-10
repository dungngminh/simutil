import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_core/simutil_core.dart';

class _FakeSession implements DeviceSession {
  _FakeSession(this.deviceId);

  @override
  final String deviceId;
  bool stopped = false;
  bool started = false;

  /// Completes the pending [start].
  final gate = Completer<void>();

  @override
  Future<void> stop() async => stopped = true;

  @override
  Future<void> start() {
    started = true;
    return gate.future;
  }

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
      final session = _FakeSession('UDID')..gate.complete();
      final cubit = StreamsCubit((_) async => session);
      await cubit.open(sim(DeviceState.booted));
      final t0 = DateTime(2026);

      cubit.onDevices([sim(DeviceState.shutdown)], now: t0);
      expect(cubit.stateValue.isOpen('UDID'), isTrue);

      cubit
        ..onDevices([
          sim(DeviceState.booted),
        ], now: t0.add(const Duration(seconds: 10)))
        ..onDevices([], now: t0.add(const Duration(seconds: 20)));
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

  group('open queue', () {
    Device android(String id) => Device.android(
      id: id,
      name: id,
      state: DeviceState.booted,
      type: DeviceType.simulator,
    );

    late Map<String, _FakeSession> sessions;
    late List<String> created;
    late StreamsCubit cubit;

    setUp(() {
      sessions = {};
      created = [];
      cubit = StreamsCubit((device) async {
        created.add(device.id);
        return sessions[device.id] = _FakeSession(device.id);
      });
    });

    test('starts one session at a time in FIFO order', () async {
      final first = cubit.open(android('a'));
      final second = cubit.open(android('b'));
      await pumpEventQueue();
      expect(created, ['a']);
      expect(sessions['a']!.started, isTrue);
      expect(
        cubit.stateValue.entries.map((e) => e.status),
        everyElement(const SessionConnecting()),
        reason: 'queued tiles show connecting',
      );

      sessions['a']!.gate.complete();
      await first;
      await pumpEventQueue();
      expect(created, ['a', 'b']);
      sessions['b']!.gate.complete();
      await second;
    });

    test('opening an open or queued device does not add a session', () async {
      unawaited(cubit.open(android('a')));
      unawaited(cubit.open(android('b')));
      unawaited(cubit.open(android('b')));
      await pumpEventQueue();
      sessions['a']!.gate.complete();
      await pumpEventQueue();
      expect(created, ['a', 'b']);
      expect(cubit.stateValue.entries, hasLength(2));
    });

    test('closing a queued device drops its start', () async {
      unawaited(cubit.open(android('a')));
      unawaited(cubit.open(android('b')));
      await pumpEventQueue();
      await cubit.closeStream('b');
      sessions['a']!.gate.complete();
      await pumpEventQueue();
      expect(created, ['a']);
      expect(cubit.stateValue.isOpen('b'), isFalse);
    });

    test('close and reopen while queued starts it once', () async {
      unawaited(cubit.open(android('a')));
      unawaited(cubit.open(android('b')));
      await cubit.closeStream('b');
      unawaited(cubit.open(android('b')));
      await pumpEventQueue();
      sessions['a']!.gate.complete();
      await pumpEventQueue();
      expect(created, ['a', 'b']);
    });

    test('a failed create does not stall the queue', () async {
      final cubit = StreamsCubit((device) async {
        if (device.id == 'a') throw 'no scrcpy';
        return _FakeSession(device.id)..gate.complete();
      });
      unawaited(cubit.open(android('a')));
      await cubit.open(android('b'));
      expect(
        cubit.stateValue.entries.first.status,
        const SessionFailed('no scrcpy'),
      );
      expect(cubit.sessionFor('b'), isNotNull);
    });
  });
}
