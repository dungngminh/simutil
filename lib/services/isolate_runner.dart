import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import '../models/isolate_message.dart';
import 'command_exec.dart';

/// Manages a single long-lived background isolate that executes CLI commands.
///
/// Usage:
/// ```dart
/// final runner = IsolateRunner();
/// await runner.init();
/// final result = await runner.execute('adb', ['devices']);
/// await runner.dispose();
/// ```
class IsolateRunner {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;

  int _nextId = 0;

  /// Pending requests waiting for a response, keyed by request id.
  final _pending = <int, Completer<CommandResult>>{};

  /// Whether the runner has been initialised and is ready to accept work.
  bool get isReady => _sendPort != null;

  // ── Lifecycle ──────────────────────────────────────────────────

  /// Spawn the background isolate and establish communication.
  ///
  /// Must be called once before [execute]. Safe to call multiple times;
  /// subsequent calls are no-ops if the isolate is already running.
  Future<void> init() async {
    if (_isolate != null) return;

    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _isolateEntryPoint,
      _receivePort!.sendPort,
    );

    final completer = Completer<SendPort>();

    _receivePort!.listen((message) {
      if (message is SendPort) {
        // The background isolate sends its SendPort as the first message.
        completer.complete(message);
      } else if (message is IsolateResponse) {
        _handleResponse(message);
      }
    });

    _sendPort = await completer.future;
  }

  /// Execute a CLI command on the background isolate.
  ///
  /// Returns a [CommandResult] when the process finishes.
  /// Throws if the background isolate reported an error.
  Future<CommandResult> execute(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    assert(isReady, 'IsolateRunner.init() must be called before execute()');

    final id = _nextId++;
    final completer = Completer<CommandResult>();
    _pending[id] = completer;

    _sendPort!.send(
      IsolateRequest(
        id: id,
        command: IsolateCommand.runCommand,
        executable: executable,
        arguments: arguments,
        workingDirectory: workingDirectory,
      ),
    );

    return completer.future;
  }

  /// Shut down the background isolate and clean up resources.
  Future<void> dispose() async {
    if (_sendPort != null) {
      _sendPort!.send(
        const IsolateRequest(
          id: -1,
          command: IsolateCommand.shutdown,
          executable: '',
        ),
      );
    }

    // Complete any pending futures with an error so callers don't hang.
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

  // ── Internal ───────────────────────────────────────────────────

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

  // ── Background isolate entry point ─────────────────────────────

  /// Runs inside the background isolate. Listens for [IsolateRequest]s
  /// and sends back [IsolateResponse]s.
  static void _isolateEntryPoint(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    // Send our SendPort back to the main isolate.
    mainSendPort.send(receivePort.sendPort);

    receivePort.listen((message) async {
      if (message is! IsolateRequest) return;

      if (message.command == IsolateCommand.shutdown) {
        receivePort.close();
        return;
      }

      try {
        final result = await Process.run(
          message.executable,
          message.arguments,
          workingDirectory: message.workingDirectory,
        );

        mainSendPort.send(
          IsolateResponse(
            id: message.id,
            stdout: result.stdout as String,
            stderr: result.stderr as String,
            exitCode: result.exitCode,
          ),
        );
      } catch (e) {
        mainSendPort.send(
          IsolateResponse(
            id: message.id,
            error: e.toString(),
          ),
        );
      }
    });
  }
}
