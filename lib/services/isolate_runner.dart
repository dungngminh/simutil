import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:simutil/models/isolate_message.dart';
import 'package:simutil/services/command_exec.dart';

class IsolateRunner {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;

  int _nextId = 0;

  final _pending = <int, Completer<CommandResult>>{};

  bool get isReady => _sendPort != null;

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

  Future<CommandResult> execute(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration? timeout,
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
        timeoutMs: timeout?.inMilliseconds,
      ),
    );

    return completer.future;
  }

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
