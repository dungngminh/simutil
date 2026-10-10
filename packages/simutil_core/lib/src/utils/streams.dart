import 'dart:async';

/// Merges change signals: listening subscribes to every source, cancelling
/// cancels them all. Errors from a source are dropped (a broken watcher
/// must not end the merged signal).
Stream<void> mergeStreams(Iterable<Stream<void>> sources) {
  final subscriptions = <StreamSubscription<void>>[];
  late final StreamController<void> controller;
  controller = StreamController<void>(
    onListen: () {
      for (final source in sources) {
        subscriptions.add(
          source.listen(controller.add, onError: (Object _) {}),
        );
      }
    },
    onPause: () {
      for (final s in subscriptions) {
        s.pause();
      }
    },
    onResume: () {
      for (final s in subscriptions) {
        s.resume();
      }
    },
    onCancel: () => Future.wait([for (final s in subscriptions) s.cancel()]),
  );
  return controller.stream;
}

/// Keeps a long-lived watcher alive: subscribes to [connect]()'s stream and,
/// whenever it ends or fails, connects again after an exponential backoff
/// ([minDelay] doubling up to [maxDelay]; reset after any event). Stops
/// when the listener cancels.
Stream<T> reconnecting<T>(
  Stream<T> Function() connect, {
  Duration minDelay = const Duration(seconds: 1),
  Duration maxDelay = const Duration(seconds: 30),
}) {
  late final StreamController<T> controller;
  StreamSubscription<T>? current;
  Timer? retry;
  var delay = minDelay;
  var cancelled = false;

  void open() {
    if (cancelled) return;
    void scheduleRetry() {
      current = null;
      if (cancelled) return;
      retry = Timer(delay, open);
      final doubled = delay * 2;
      delay = doubled > maxDelay ? maxDelay : doubled;
    }

    try {
      current = connect().listen(
        (event) {
          delay = minDelay;
          controller.add(event);
        },
        onError: (Object _) {},
        onDone: scheduleRetry,
        cancelOnError: false,
      );
    } catch (_) {
      scheduleRetry();
    }
  }

  controller = StreamController<T>(
    onListen: open,
    onCancel: () async {
      cancelled = true;
      retry?.cancel();
      await current?.cancel();
    },
  );
  return controller.stream;
}
