import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_app/src/devices/slim_mode_cubit.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_app/src/stream/streams_state.dart';
import 'package:simutil_app/src/ui/toasts/slim_suggestion.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_core/testing.dart';

/// Records slim writes and reports them back through [isSlim].
class _FakeSlim implements SlimControl {
  final slimmed = <String>{};
  final calls = <(String, bool)>[];

  @override
  Future<bool> isSlim(String udid) async => slimmed.contains(udid);

  @override
  Future<void> setSlim(String udid, {required bool slim}) async {
    calls.add((udid, slim));
    slim ? slimmed.add(udid) : slimmed.remove(udid);
  }
}

class _Session implements DeviceSession {
  _Session(this.deviceId);

  @override
  final String deviceId;

  @override
  SessionStatus get status => const SessionLive(width: 1, height: 2);

  @override
  Stream<SessionStatus> get statusChanges => Stream.value(status);

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  bool get isRecording => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Device _sim(String id, [DeviceState state = DeviceState.booted]) =>
    Device.ios(id: id, name: id, state: state, type: DeviceType.simulator);

Device _android(String id) => Device.android(
  id: id,
  name: id,
  state: DeviceState.booted,
  type: DeviceType.simulator,
);

void main() {
  late _FakeSlim slim;
  late FakeDeviceService ios;
  late DevicesCubit devices;
  late StreamsCubit streams;
  late SlimModeCubit mode;
  late List<String> created;
  var slimOnLaunch = false;

  setUp(() async {
    slim = _FakeSlim();
    ios = FakeDeviceService(simulators: [_sim('a'), _sim('b')]);
    devices = DevicesCubit(
      android: FakeDeviceService(simulators: [_android('pixel')]),
      ios: ios,
      slim: slim,
      slimOnLaunch: () => slimOnLaunch,
      loadIos: true,
    );
    await devices.refresh();
    created = [];
    streams = StreamsCubit((device) async {
      created.add(device.id);
      return _Session(device.id);
    });
    mode = SlimModeCubit(devices: devices, streams: streams);
    slimOnLaunch = false;
  });

  tearDown(() async {
    await mode.close();
    await streams.close();
    await devices.close();
  });

  test(
    'setMode slims each streamed simulator in turn and reopens it',
    () async {
      for (final d in [_sim('a'), _sim('b'), _android('pixel')]) {
        await streams.open(d);
      }
      expect(created, ['a', 'b', 'pixel']);

      await mode.setMode(enabled: true);

      expect(slim.calls, [('a', true), ('b', true)]); // Android untouched
      expect(devices.stateValue.slimmed, {'a', 'b'});
      await pumpEventQueue();
      expect(streams.stateValue.entries.map((e) => e.device.id).toSet(), {
        'a',
        'b',
        'pixel',
      });
      expect(created, ['a', 'b', 'pixel', 'a', 'b']); // fresh sessions
      expect(mode.stateValue, const SlimModeState(enabled: true));

      // Already slim: nothing to reboot.
      await mode.setMode(enabled: true);
      expect(slim.calls, hasLength(2));
    },
  );

  test('launch writes slim first only in Slim mode', () async {
    await devices.launch(_sim('c', DeviceState.shutdown));
    expect(slim.calls, isEmpty);

    slimOnLaunch = true;
    await devices.launch(_sim('d', DeviceState.shutdown));
    expect(slim.calls, [('d', true)]);
    expect(ios.launched.map((l) => l.deviceId), ['c', 'd']);
  });

  group('shouldSuggestSlim', () {
    StreamEntry entry(Device d) =>
        StreamEntry(device: d, status: const SessionConnecting());

    test('needs two or more non-slim simulators and the mode off', () {
      final two = [entry(_sim('a')), entry(_sim('b'))];
      expect(
        shouldSuggestSlim(entries: two, slimmed: {}, slimEnabled: false),
        isTrue,
      );
      expect(
        shouldSuggestSlim(entries: two, slimmed: {}, slimEnabled: true),
        isFalse,
      );
      expect(
        shouldSuggestSlim(
          entries: two,
          slimmed: {'a', 'b'},
          slimEnabled: false,
        ),
        isFalse,
      );
      expect(
        shouldSuggestSlim(
          entries: [entry(_sim('a')), entry(_android('pixel'))],
          slimmed: {},
          slimEnabled: false,
        ),
        isFalse,
      );
    });
  });
}
