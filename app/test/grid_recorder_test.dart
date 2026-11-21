import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/recording/grid_recorder.dart';
import 'package:simutil_app/src/recording/recording_lock.dart';

void main() {
  const channel = MethodChannel('simutil/grid_recorder');

  testWidgets(
    'a second start while starting joins it and keeps the lock',
    (tester) async {
      final lock = RecordingLock();
      final cubit = GridRecorderCubit(recordingLock: lock);
      final gate = Completer<void>();
      var nativeStarts = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method != 'start') return null;
        nativeStarts++;
        await gate.future;
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: cubit.boundaryKey,
          child: const SizedBox(width: 100, height: 100),
        ),
      );

      final first = cubit.start('/tmp/grid.mp4');
      final second = cubit.start('/tmp/grid.mp4');
      gate.complete();
      await first;
      await second;

      expect(nativeStarts, 1);
      expect(cubit.isRecording, isTrue);
      expect(lock.holder, 'grid');
    },
    // The native ScreenCaptureKit path; elsewhere it pipes into ffmpeg.
    skip: !Platform.isMacOS,
  );

  testWidgets('a stop while starting waits and stops that recording', (
    tester,
  ) async {
    final lock = RecordingLock();
    final cubit = GridRecorderCubit(recordingLock: lock);
    final gate = Completer<void>();
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      if (call.method == 'start') await gate.future;
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: cubit.boundaryKey,
        child: const SizedBox(width: 100, height: 100),
      ),
    );

    final starting = cubit.start('/tmp/grid.mp4');
    final stopping = cubit.stop();
    gate.complete();
    await starting;
    await stopping;

    expect(calls, ['start', 'stop']);
    expect(cubit.isRecording, isFalse);
    expect(lock.holder, isNull);
  }, skip: !Platform.isMacOS);
}
