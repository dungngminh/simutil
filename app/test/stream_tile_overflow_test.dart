import 'dart:async';

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/recording/grid_recorder.dart';
import 'package:simutil_app/src/settings/device_settings_cubit.dart';
import 'package:simutil_app/src/settings/view_settings_cubit.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_app/src/ui/streams/stream_grid.dart';
import 'package:simutil_app/src/ui/streams/stream_tile.dart';
import 'package:simutil_core/simutil_core.dart';

class _FakeSession implements DeviceSession {
  _FakeSession(this.deviceId);

  @override
  final String deviceId;
  final _status = StreamController<SessionStatus>.broadcast();

  void emit(SessionStatus status) => _status.add(status);

  @override
  Future<void> stop() async {}

  @override
  Future<void> start() async {}

  @override
  Stream<SessionStatus> get statusChanges => _status.stream;

  @override
  SessionStatus get status => const SessionConnecting();

  @override
  List<DeviceButton> get buttons => DeviceButton.values;

  @override
  bool get isRecording => false;

  @override
  void touch(TouchPhase phase, double x, double y) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Device _emulator(int i) => Device.android(
  id: 'emulator-555$i',
  name: 'Pixel 9 Pro XL with a rather long name $i',
  state: DeviceState.booted,
  type: DeviceType.simulator,
);

void main() {
  late StreamsCubit streams;
  late ViewSettingsCubit view;
  late Map<String, _FakeSession> sessions;

  setUp(() {
    sessions = {};
    streams = StreamsCubit(
      (device) async => sessions[device.id] = _FakeSession(device.id),
    );
    view = ViewSettingsCubit();
  });

  Widget app(Widget child) => MultiBlocSignalProvider(
    providers: [
      BlocSignalProvider<StreamsCubit>.value(value: streams),
      BlocSignalProvider<ViewSettingsCubit>.value(value: view),
      BlocSignalProvider<DeviceSettingsCubit>(
        create: (_) => DeviceSettingsCubit(),
      ),
      BlocSignalProvider<GridRecorderCubit>(create: (_) => GridRecorderCubit()),
    ],
    child: MaterialApp(
      theme: simuTheme(Brightness.light),
      home: Scaffold(body: child),
    ),
  );

  Future<void> openStreams(WidgetTester tester, int count) async {
    for (var i = 0; i < count; i++) {
      await streams.open(_emulator(i));
    }
    // One failed, the rest live (one with blocked input) so every body
    // variant gets laid out.
    sessions.values.first.emit(const SessionFailed('scrcpy exited early'));
    for (final s in sessions.values.skip(1)) {
      s.emit(const SessionLive(width: 1080, height: 2400, inputBlocked: true));
    }
    await tester.pump();
  }

  testWidgets('a tile never overflows, at any size or mode', (tester) async {
    await openStreams(tester, 2);
    const sizes = [
      Size(24, 24),
      Size(60, 50),
      Size(110, 90),
      Size(160, 140),
      Size(230, 200),
      Size(320, 260),
      Size(700, 520),
    ];
    for (final entry in streams.stateValue.entries) {
      for (final mode in StreamTileMode.values) {
        for (final size in sizes) {
          await tester.pumpWidget(
            app(
              Center(
                child: SizedBox.fromSize(
                  size: size,
                  child: StreamTile(entry: entry, mode: mode),
                ),
              ),
            ),
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.status} $mode $size',
          );
        }
      }
    }
  });

  testWidgets('layout switches animate without overflow', (tester) async {
    tester.view
      ..physicalSize = const Size(1100, 700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await openStreams(tester, 4);
    await tester.pumpWidget(app(const StreamGrid()));
    await tester.pumpAndSettle();

    for (final layout in [
      StreamLayout.spotlightVertical,
      StreamLayout.spotlightHorizontal,
      StreamLayout.grid,
      StreamLayout.spotlightHorizontal,
    ]) {
      view.setLayout(layout);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.takeException(), isNull, reason: '$layout frame $i');
      }
    }
    // Clicking a thumbnail in the bottom strip spotlights it.
    final thumb = streams.stateValue.entries.last.device;
    await tester.tap(find.text(thumb.name));
    await tester.pumpAndSettle();
    expect(view.stateValue.spotlightId, thumb.id);
    expect(view.stateValue.layout, StreamLayout.spotlightHorizontal);
  });
}
