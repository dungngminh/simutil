import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:test/test.dart';

void main() {
  test('mergeStreams forwards every source and cancels them all', () async {
    final a = StreamController<void>();
    final b = StreamController<void>();
    var count = 0;
    final sub = mergeStreams([a.stream, b.stream]).listen((_) => count++);
    a.add(null);
    b
      ..add(null)
      ..addError('ignored');
    await pumpEventQueue();
    expect(count, 2);
    await sub.cancel();
    expect(a.hasListener || b.hasListener, isFalse);
  });

  test('reconnecting retries with backoff and resets after events', () {
    fakeAsync((async) {
      final sources = <StreamController<int>>[];
      final events = <int>[];
      final sub = reconnecting(() {
        final c = StreamController<int>();
        sources.add(c);
        return c.stream;
      }).listen(events.add);

      async.flushMicrotasks();
      expect(sources, hasLength(1));
      unawaited(sources[0].close()); // adb server died
      async.elapse(const Duration(milliseconds: 999));
      expect(sources, hasLength(1));
      async.elapse(const Duration(milliseconds: 1));
      expect(sources, hasLength(2)); // after 1 s

      unawaited(sources[1].close());
      async.elapse(const Duration(seconds: 2));
      expect(sources, hasLength(3)); // after 2 s

      sources[2].add(7); // healthy again: backoff resets
      unawaited(sources[2].close());
      async.elapse(const Duration(seconds: 1));
      expect(sources, hasLength(4));
      expect(events, [7]);

      unawaited(sub.cancel());
      async.flushMicrotasks();
      expect(sources.last.hasListener, isFalse);
      async.elapse(const Duration(minutes: 1));
      expect(sources, hasLength(4));
    });
  });
}
