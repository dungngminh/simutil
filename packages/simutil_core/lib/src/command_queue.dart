import 'dart:async';
import 'dart:collection';

/// How urgently a command should run.
enum CommandPriority {
  /// Started by the user (launch, shut down, stream); never waits behind
  /// background work.
  interactive,

  /// Default for commands with no special needs.
  normal,

  /// Polling and probes. Must be idempotent queries: identical background
  /// commands that are queued or running share one result.
  background,
}

/// Bounded-concurrency priority scheduler for process jobs.
///
/// - Runs at most [maxConcurrent] jobs at once, highest priority first,
///   FIFO within a priority.
/// - Background jobs may hold at most `maxConcurrent - 1` slots, so a slot
///   is always free for interactive / normal work.
/// - A background job waiting longer than [starvationLimit] runs next
///   regardless of priority.
/// - Background jobs with the same key are single-flight: later callers get
///   the pending job's future instead of a new job.
class CommandQueue<T> {
  /// Creates a queue running up to [maxConcurrent] (at least 2) jobs.
  CommandQueue({
    int maxConcurrent = 4,
    this.starvationLimit = const Duration(seconds: 2),
    DateTime Function()? clock,
  }) : maxConcurrent = maxConcurrent < 2 ? 2 : maxConcurrent,
       _now = clock ?? DateTime.now;

  /// Most jobs running at once.
  final int maxConcurrent;

  /// Longest a background job waits before it jumps the queue.
  final Duration starvationLimit;

  final DateTime Function() _now;
  final _queues = {
    for (final priority in CommandPriority.values) priority: Queue<_Job<T>>(),
  };
  final _shared = <Object, _Job<T>>{};
  int _running = 0;
  int _runningBackground = 0;
  bool _closed = false;

  /// Jobs waiting to start.
  int get pending => _queues.values.fold(0, (n, q) => n + q.length);

  /// Jobs currently running.
  int get running => _running;

  /// Schedules [start] at [priority]; [key] identifies identical background
  /// work for single-flight sharing.
  Future<T> add(
    Future<T> Function() start, {
    CommandPriority priority = CommandPriority.normal,
    Object? key,
  }) {
    if (_closed) return Future.error(StateError('CommandQueue is closed'));
    final background = priority == CommandPriority.background;
    if (background && key != null) {
      if (_shared[key] case final job?) return job.completer.future;
    }
    final job = _Job<T>(start, priority, background ? key : null, _now());
    if (job.key case final key?) _shared[key] = job;
    _queues[priority]!.add(job);
    _pump();
    return job.completer.future;
  }

  /// Fails every job that has not started; running jobs finish normally.
  void close() {
    _closed = true;
    for (final queue in _queues.values) {
      for (final job in queue) {
        job.completer.completeError(StateError('CommandQueue closed'));
      }
      queue.clear();
    }
    _shared.clear();
  }

  void _pump() {
    while (_running < maxConcurrent) {
      final job = _next();
      if (job == null) return;
      unawaited(_run(job));
    }
  }

  _Job<T>? _next() {
    final background = _queues[CommandPriority.background]!;
    final backgroundAllowed = _runningBackground < maxConcurrent - 1;
    if (backgroundAllowed &&
        background.isNotEmpty &&
        _now().difference(background.first.queuedAt) >= starvationLimit) {
      return background.removeFirst();
    }
    for (final MapEntry(key: priority, value: queue) in _queues.entries) {
      if (queue.isEmpty) continue;
      if (priority == CommandPriority.background && !backgroundAllowed) {
        return null;
      }
      return queue.removeFirst();
    }
    return null;
  }

  Future<void> _run(_Job<T> job) async {
    final background = job.priority == CommandPriority.background;
    _running++;
    if (background) _runningBackground++;
    try {
      job.completer.complete(await job.start());
    } catch (e, st) {
      job.completer.completeError(e, st);
    } finally {
      _running--;
      if (background) _runningBackground--;
      if (job.key case final key? when identical(_shared[key], job)) {
        _shared.remove(key);
      }
      if (!_closed) _pump();
    }
  }
}

class _Job<T> {
  _Job(this.start, this.priority, this.key, this.queuedAt);

  final Future<T> Function() start;
  final CommandPriority priority;
  final Object? key;
  final DateTime queuedAt;
  final completer = Completer<T>();
}
