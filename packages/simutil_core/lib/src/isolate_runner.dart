import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:simutil_core/src/command_exec.dart';
import 'package:simutil_core/src/command_queue.dart';
import 'package:simutil_core/src/models/isolate_message.dart';

/// Runs shell commands on a background isolate so the UI isolate stays
/// responsive, through a [CommandQueue]: bounded concurrency, priorities
/// (user actions never wait behind polling) and single-flight background
/// queries.
class IsolateRunner {
  /// Creates a runner allowing [maxConcurrent] processes at once (default:
  /// processor count, clamped to 2..6).
  IsolateRunner({int? maxConcurrent})
    : _queue = CommandQueue<CommandResult>(
        maxConcurrent: maxConcurrent ?? Platform.numberOfProcessors.clamp(2, 6),
      );

  final CommandQueue<CommandResult> _queue;

  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;

  int _nextId = 0;

  final _pending = <int, Completer<CommandResult>>{};

  /// Whether [init] completed and [execute] may be called.
  bool get isReady => _sendPort != null;

  /// Spawns the worker isolate. Safe to call more than once.
  Future<void> init() async {
    if (_isolate != null) return;

    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_isolateEntryPoint, _receivePort!.sendPort);

    final completer = Completer<SendPort>();

    _receivePort!.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      } else if (message is IsolateResponse) {
        _handleResponse(message);
      }
    });

    _sendPort = await completer.future;
  }

  /// Runs [executable] with [arguments] on the worker isolate once the
  /// queue gives it a slot; [timeout] counts from process start.
  Future<CommandResult> execute(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration? timeout,
    CommandPriority priority = CommandPriority.normal,
  }) {
    assert(isReady, 'IsolateRunner.init() must be called before execute()');
    return _queue.add(
      () => _send(executable, arguments, workingDirectory, timeout),
      priority: priority,
      key: [workingDirectory ?? '', executable, ...arguments].join('\u0000'),
    );
  }

  Future<CommandResult> _send(
    String executable,
    List<String> arguments,
    String? workingDirectory,
    Duration? timeout,
  ) {
    final sendPort = _sendPort;
    if (sendPort == null) {
      return Future.error(StateError('IsolateRunner disposed'));
    }
    final id = _nextId++;
    final completer = Completer<CommandResult>();
    _pending[id] = completer;

    sendPort.send(
      IsolateRequest(
        id: id,
        command: IsolateCommand.runCommand,
        executable: executable,
        arguments: arguments,
        workingDirectory: workingDirectory,
        timeoutMs: timeout?.inMilliseconds,
      ),
    );

    return completer.future;
  }

  /// Stops the worker isolate and fails any in-flight requests.
  Future<void> dispose() async {
    _queue.close();
    if (_sendPort != null) {
      _sendPort!.send(
        const IsolateRequest(
          id: -1,
          command: IsolateCommand.shutdown,
          executable: '',
        ),
      );
    }

    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('IsolateRunner disposed while request was pending'),
        );
      }
    }
    _pending.clear();

    _receivePort?.close();
    _isolate?.kill(priority: Isolate.beforeNextEvent);
    _isolate = null;
    _sendPort = null;
    _receivePort = null;
  }

  void _handleResponse(IsolateResponse response) {
    final completer = _pending.remove(response.id);
    if (completer == null) return;

    if (response.error != null) {
      completer.completeError(Exception(response.error));
    } else {
      completer.complete(
        CommandResult(
          stdout: response.stdout,
          stderr: response.stderr,
          exitCode: response.exitCode,
        ),
      );
    }
  }

  static void _isolateEntryPoint(SendPort mainSendPort) {
    final receivePort = ReceivePort();

    mainSendPort.send(receivePort.sendPort);

    receivePort.listen((message) async {
      if (message is! IsolateRequest) return;

      if (message.command == IsolateCommand.shutdown) {
        receivePort.close();
        return;
      }

      try {
        final process = await Process.start(
          message.executable,
          message.arguments,
          workingDirectory: message.workingDirectory,
        );
        // Match Process.run: the child sees EOF on stdin instead of hanging.
        unawaited(process.stdin.close());
        final stdoutFuture = process.stdout
            .transform(SystemEncoding().decoder)
            .join();
        final stderrFuture = process.stderr
            .transform(SystemEncoding().decoder)
            .join();
        final timeout = message.timeoutMs == null
            ? null
            : Duration(milliseconds: message.timeoutMs!);
        final exitCode = timeout == null
            ? await process.exitCode
            : await process.exitCode.timeout(
                timeout,
                onTimeout: () {
                  process.kill(ProcessSignal.sigkill);
                  throw TimeoutException(
                    'Command timed out after ${timeout.inSeconds} seconds',
                  );
                },
              );
        final stdout = await stdoutFuture;
        final stderr = await stderrFuture;

        mainSendPort.send(
          IsolateResponse(
            id: message.id,
            stdout: stdout,
            stderr: stderr,
            exitCode: exitCode,
          ),
        );
      } catch (e) {
        mainSendPort.send(IsolateResponse(id: message.id, error: e.toString()));
      }
    });
  }
}
