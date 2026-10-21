import 'dart:async';
import 'dart:io';

import 'package:grpc/grpc.dart';
import 'package:simutil_adb/src/emulator/emulator_endpoint.dart';
import 'package:simutil_adb/src/emulator/emulator_input.dart';
import 'package:simutil_adb/src/emulator/generated/emulator_controller.pbgrpc.dart';
import 'package:simutil_adb/src/ffmpeg.dart';
import 'package:simutil_core/simutil_core.dart';

/// One frame [EmulatorGrpcSession.frames] wrote: [width]x[height] packed
/// RGB888 pixels at the start of the shared file.
typedef EmulatorFrame = ({int width, int height});

/// Streams and controls an Android emulator over its own gRPC API, the way
/// Android Studio's embedded emulator does: raw frames through a shared file
/// (no video codec in the guest) and input through `streamInputEvent`.
abstract interface class EmulatorGrpcSession implements DeviceSession {
  /// Creates a session for emulator [serial] served at [endpoint]; call
  /// [start] to connect. [adbPath] and [exec] run `adb emu` for recording.
  factory EmulatorGrpcSession({
    required String serial,
    required EmulatorEndpoint endpoint,
    required String adbPath,
    required CommandExec exec,
  }) = _EmulatorGrpcSession;

  /// Writes each new screen frame, scaled to fit [width]x[height] pixels
  /// (capped at the display size), into the file at [path] and reports its
  /// size. The file must hold `width * height * 3` bytes; the emulator maps
  /// it itself. Listen again with a new size to resize.
  Stream<EmulatorFrame> frames({
    required String path,
    required int width,
    required int height,
  });

  /// Types [text]; characters outside printable ASCII are dropped.
  void typeText(String text);

  /// Presses and releases [key], a W3C `KeyboardEvent.key` value
  /// (`Enter`, `Backspace`, `ArrowUp`…).
  void pressKey(String key);
}

class _EmulatorGrpcSession implements EmulatorGrpcSession {
  _EmulatorGrpcSession({
    required this.serial,
    required EmulatorEndpoint endpoint,
    required this.adbPath,
    required CommandExec exec,
  }) : _exec = exec,
       _channel = ClientChannel(
         InternetAddress.loopbackIPv4,
         port: endpoint.port,
         options: const ChannelOptions(
           credentials: ChannelCredentials.insecure(),
         ),
       ),
       _metadata = {
         if (endpoint.token case final token?) 'authorization': 'Bearer $token',
       };

  final String serial;
  final String adbPath;
  final CommandExec _exec;
  final ClientChannel _channel;
  final Map<String, String> _metadata;
  late final _client = EmulatorControllerClient(
    _channel,
    options: CallOptions(metadata: _metadata),
  );

  final _statusController = StreamController<SessionStatus>.broadcast();
  SessionStatus _status = const SessionConnecting();
  StreamController<InputEvent>? _input;
  bool _stopped = false;

  /// Display size in its natural orientation, and the current rotation.
  int? _width;
  int? _height;
  var _rotation = Rotation_SkinRotation.PORTRAIT;
  String? _recordingPath;

  @override
  String get deviceId => serial;

  @override
  List<DeviceButton> get buttons => const [
    DeviceButton.back,
    DeviceButton.home,
    DeviceButton.recents,
  ];

  @override
  SessionStatus get status => _status;

  @override
  Stream<SessionStatus> get statusChanges => _statusController.stream;

  void _emit(SessionStatus status) {
    if (_stopped && status is! SessionFailed) return;
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  @override
  Future<void> start() async {
    _emit(const SessionConnecting());
    try {
      await _readDisplay();
      if (_stopped) return;
      _input = StreamController<InputEvent>();
      unawaited(
        _client
            .streamInputEvent(_input!.stream)
            .then<void>(
              (_) {},
              onError: (Object e) {
                if (!_stopped) {
                  _emit(const SessionFailed('Emulator disconnected'));
                }
              },
            ),
      );
      _emitLive();
    } catch (e) {
      // Emit before stop(): it closes the status stream.
      _emit(SessionFailed(e is GrpcError ? 'gRPC: ${e.message}' : '$e'));
      await stop();
    }
  }

  /// A cold boot can take minutes before the display shows anything.
  static const _bootTimeout = Duration(minutes: 3);

  /// Reads the display size from a full-size screenshot (an oversized
  /// request is capped at the display); 0x0 until the display is on.
  Future<void> _readDisplay() async {
    final deadline = DateTime.now().add(_bootTimeout);
    while (!_stopped) {
      final image = await _client.getScreenshot(
        ImageFormat(
          format: ImageFormat_ImgFormat.RGB888,
          width: 1 << 16,
          height: 1 << 16,
        ),
        options: CallOptions(timeout: const Duration(seconds: 10)),
      );
      final format = image.format;
      if (format.width > 0 && format.height > 0) {
        _rotation = format.rotation.rotation;
        final swap = _sideways(_rotation);
        _width = swap ? format.height : format.width;
        _height = swap ? format.width : format.height;
        return;
      }
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('emulator display did not turn on');
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  static bool _sideways(Rotation_SkinRotation rotation) =>
      rotation == Rotation_SkinRotation.LANDSCAPE ||
      rotation == Rotation_SkinRotation.REVERSE_LANDSCAPE;

  void _emitLive() {
    final (width, height) = (_width, _height);
    if (width == null || height == null || _input == null) return;
    final swap = _sideways(_rotation);
    _emit(
      SessionLive(width: swap ? height : width, height: swap ? width : height),
    );
  }

  @override
  Stream<EmulatorFrame> frames({
    required String path,
    required int width,
    required int height,
  }) => _client
      .streamScreenshot(
        ImageFormat(
          format: ImageFormat_ImgFormat.RGB888,
          width: width,
          height: height,
          transport: ImageTransport(
            channel: ImageTransport_TransportChannel.MMAP,
            handle: Uri.file(path).toString(),
          ),
        ),
      )
      .where((image) => image.format.width > 0 && image.format.height > 0)
      .map((image) {
        final rotation = image.format.rotation.rotation;
        if (rotation != _rotation) {
          _rotation = rotation;
          _emitLive();
        }
        return (width: image.format.width, height: image.format.height);
      });

  @override
  void touch(TouchPhase phase, double x, double y) {
    final (width, height) = (_width, _height);
    if (width == null || height == null) return;
    _send(
      EmulatorInput.touch(
        phase,
        x,
        y,
        width: width,
        height: height,
        rotation: _rotation,
      ),
    );
  }

  @override
  void press(DeviceButton button) =>
      _send(EmulatorInput.key(EmulatorInput.buttonKey(button)));

  @override
  void typeText(String text) => _send(EmulatorInput.text(text));

  @override
  void pressKey(String key) => _send(EmulatorInput.key(key));

  void _send(InputEvent event) {
    final input = _input;
    if (input != null && !input.isClosed) input.add(event);
  }

  @override
  Future<void> repairInput() async {}

  @override
  bool get isRecording => _recordingPath != null;

  /// The emulator records its display itself (VP9 `.webm`, host-side); on
  /// stop it is converted to [path] with ffmpeg when available.
  @override
  Future<void> startRecording(String path) async {
    if (_recordingPath != null) return;
    final result = await _emu([
      'screenrecord',
      'start',
      '--time-limit',
      '14400',
      '$path.webm',
    ]);
    // `adb emu` exits 0 even when the console says KO.
    if (!result.success || result.stdout.contains('KO')) {
      throw StateError('Recording failed: ${result.stdout.trim()}');
    }
    _recordingPath = path;
  }

  @override
  Future<String?> stopRecording() async {
    final path = _recordingPath;
    _recordingPath = null;
    if (path == null) return null;
    await _emu(['screenrecord', 'stop']);
    final converted = await runFfmpeg(_exec, [
      '-y',
      '-loglevel',
      'error',
      '-i',
      '$path.webm',
      '-vf',
      'pad=ceil(iw/2)*2:ceil(ih/2)*2',
      ...h264EncoderArgs,
      '-pix_fmt',
      'yuv420p',
      path,
    ], timeout: const Duration(minutes: 10));
    if (!converted) return '$path.webm';
    await File('$path.webm').delete();
    return path;
  }

  Future<CommandResult> _emu(List<String> args) => _exec.run(
    adbPath,
    arguments: ['-s', serial, 'emu', ...args],
    priority: CommandPriority.interactive,
  );

  @override
  Future<void> stop() async {
    if (_stopped) return;
    await stopRecording();
    _stopped = true;
    unawaited(_input?.close());
    await _channel.shutdown();
    await _statusController.close();
  }
}
