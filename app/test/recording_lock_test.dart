import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/recording/recording_lock.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_core/simutil_core.dart';

class _RecordingSession implements DeviceSession {
  _RecordingSession(this.deviceId);

  @override
  final String deviceId;

  @override
  bool isRecording = false;

  @override
  SessionStatus get status => const SessionLive(width: 1080, height: 2400);

  @override
  Stream<SessionStatus> get statusChanges => Stream.value(status);

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async => isRecording = false;

  @override
  Future<void> startRecording(String path) async => isRecording = true;

  @override
  Future<String?> stopRecording() async {
    isRecording = false;
    return '/tmp/$deviceId.mp4';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('lock allows one holder at a time', () {
    final lock = RecordingLock()..acquire('grid', label: 'the grid');
    expect(
      () => lock.acquire('pixel', label: 'Pixel 7'),
      throwsA(
        isA<RecordingInProgress>().having(
          (e) => '$e',
          'message',
          contains('the grid'),
        ),
      ),
    );
    lock
      ..acquire('grid', label: 'the grid') // re-entrant for the holder
      ..release('pixel'); // not the holder: no-op
    expect(lock.holder, 'grid');
    lock.release('grid');
    expect(() => lock.acquire('pixel', label: 'Pixel 7'), returnsNormally);
  });

  test('a second device cannot record until the first stops', () async {
    final lock = RecordingLock();
    final cubit = StreamsCubit(
      (device) async => _RecordingSession(device.id),
      recordingLock: lock,
    );
    Device sim(String id) => Device.ios(
      id: id,
      name: id,
      state: DeviceState.booted,
      type: DeviceType.simulator,
    );
    await cubit.open(sim('a'));
    await cubit.open(sim('b'));
    await pumpEventQueue();

    await cubit.toggleRecording('a', '/tmp');
    await expectLater(
      cubit.toggleRecording('b', '/tmp'),
      throwsA(isA<RecordingInProgress>()),
    );
    expect(cubit.sessionFor('b')!.isRecording, isFalse);

    await cubit.toggleRecording('a', '/tmp'); // stop
    await cubit.toggleRecording('b', '/tmp');
    expect(cubit.sessionFor('b')!.isRecording, isTrue);

    await cubit.closeStream('b'); // closing frees the lock
    expect(lock.holder, isNull);
    await cubit.close();
  });
}
