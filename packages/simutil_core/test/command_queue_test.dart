import 'dart:async';

import 'package:simutil_core/simutil_core.dart';
import 'package:test/test.dart';

void main() {
  /// A job that finishes when its completer does, logging its start.
  Future<String> Function() job(
    String name,
    List<String> started,
    Map<String, Completer<String>> gates,
  ) {
    final gate = gates[name] = Completer<String>();
    return () {
      started.add(name);
      return gate.future;
    };
  }

  test('runs at most maxConcurrent, highest priority first', () async {
    final queue = CommandQueue<String>(maxConcurrent: 2);
    final started = <String>[];
    final gates = <String, Completer<String>>{};
    final results = [
      queue.add(job('a', started, gates)),
      queue.add(job('b', started, gates)),
      queue.add(
        job('bg', started, gates),
        priority: CommandPriority.background,
        key: 'bg',
      ),
      queue.add(
        job('user', started, gates),
        priority: CommandPriority.interactive,
      ),
    ];
    await pumpEventQueue();
    expect(started, ['a', 'b']);
    expect(queue.pending, 2);

    gates['a']!.complete('a');
    await pumpEventQueue();
    expect(started, ['a', 'b', 'user']);

    gates['b']!.complete('b');
    await pumpEventQueue();
    expect(started.last, 'bg');
    gates['user']!.complete('user');
    gates['bg']!.complete('bg');
    expect(await Future.wait(results), ['a', 'b', 'bg', 'user']);
  });

  test('background never takes the last slot', () async {
    final queue = CommandQueue<String>(maxConcurrent: 2);
    final started = <String>[];
    final gates = <String, Completer<String>>{};
    for (final name in ['p1', 'p2']) {
      unawaited(
        queue.add(
          job(name, started, gates),
          priority: CommandPriority.background,
          key: name,
        ),
      );
    }
    await pumpEventQueue();
    expect(started, ['p1']);

    unawaited(
      queue.add(
        job('user', started, gates),
        priority: CommandPriority.interactive,
      ),
    );
    await pumpEventQueue();
    expect(started, ['p1', 'user']);
  });

  test('identical background work is single-flight', () async {
    final queue = CommandQueue<String>(maxConcurrent: 2);
    var runs = 0;
    final gate = Completer<String>();
    Future<String> poll() {
      runs++;
      return gate.future;
    }

    final first = queue.add(
      poll,
      priority: CommandPriority.background,
      key: 'adb devices',
    );
    final second = queue.add(
      poll,
      priority: CommandPriority.background,
      key: 'adb devices',
    );
    gate.complete('list');
    expect(await Future.wait([first, second]), ['list', 'list']);
    expect(runs, 1);

    // Interactive work with the same key is never merged.
    final user = await queue.add(
      () async => 'tap',
      priority: CommandPriority.interactive,
      key: 'adb devices',
    );
    expect(user, 'tap');
  });

  test('starving background work jumps the queue', () async {
    var now = DateTime(2026);
    final queue = CommandQueue<String>(maxConcurrent: 2, clock: () => now);
    final started = <String>[];
    final gates = <String, Completer<String>>{};
    unawaited(queue.add(job('a', started, gates)));
    unawaited(queue.add(job('b', started, gates)));
    unawaited(
      queue.add(
        job('bg', started, gates),
        priority: CommandPriority.background,
        key: 'bg',
      ),
    );
    unawaited(queue.add(job('c', started, gates)));
    await pumpEventQueue();

    now = now.add(const Duration(seconds: 3));
    gates['a']!.complete('a');
    await pumpEventQueue();
    expect(started, ['a', 'b', 'bg']);
  });

  test(
    'errors propagate and free the slot; close fails pending jobs',
    () async {
      final queue = CommandQueue<String>(maxConcurrent: 2);
      await expectLater(
        queue.add(() async => throw StateError('boom')),
        throwsStateError,
      );
      expect(queue.running, 0);

      final blocker = Completer<String>();
      unawaited(queue.add(() => blocker.future));
      unawaited(queue.add(() => blocker.future));
      final waiting = queue.add(() async => 'never');
      queue.close();
      await expectLater(waiting, throwsStateError);
      blocker.complete('done');
    },
  );
}
