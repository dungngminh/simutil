import 'dart:async';

import 'package:flutter/services.dart';
import 'package:simutil_apple/simutil_apple.dart';
import 'package:simutil_core/simutil_core.dart';

import 'package:simutil_app/src/stream/stream_fps.dart';
import 'package:simutil_app/src/stream/ios/apple_chrome.dart';

/// [DeviceSession] for a booted iOS simulator, backed by the native
/// `SimStreamPlugin` (macOS): the framebuffer is a Flutter texture and input
/// goes through SimulatorKit's HID client.
class IosSimSession implements DeviceSession {
  /// Creates a session for simulator [udid]; call [start] to connect.
  IosSimSession(this.udid, {required CommandExec exec})
    : _exec = exec,
      _recorder = SimulatorRecorder(udid) {
    _ensureHandler();
  }

  /// Simulator UDID.
  final String udid;
  final CommandExec _exec;
  final SimulatorRecorder _recorder;

  static const _channel = MethodChannel('simutil/ios_stream');
  static final _active = <String, IosSimSession>{};
  static var _handlerSet = false;

  /// Set by Xcode 27 Device Hub when it takes over input from the legacy HID
  /// path (see serve-sim `device-hub-input.ts`).
  static const _deviceHubInputKey = 'com.apple.coredevice.dtuhidd.active';

  final _statusController = StreamController<SessionStatus>.broadcast();
  SessionStatus _status = const SessionConnecting();
  bool _inputBlocked = false;
  int? _width;
  int? _height;

  /// Texture id once [start] succeeded.
  int? textureId;

  /// Apple's device frame, when Xcode has one for this device type.
  AppleChrome? chrome;

  static void _ensureHandler() {
    if (_handlerSet) return;
    _handlerSet = true;
    _channel.setMethodCallHandler((call) async {
      final args = (call.arguments as Map).cast<String, Object?>();
      if (call.method == 'size') {
        _active[args['udid']]?._live(
          args['width']! as int,
          args['height']! as int,
        );
      }
    });
  }

  void _emit(SessionStatus status) {
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  void _live(int width, int height) {
    _width = width;
    _height = height;
    _emit(
      SessionLive(width: width, height: height, inputBlocked: _inputBlocked),
    );
  }

  @override
  String get deviceId => udid;

  @override
  List<DeviceButton> get buttons => const [
    DeviceButton.home,
    DeviceButton.recents,
    DeviceButton.lock,
  ];

  @override
  SessionStatus get status => _status;

  @override
  Stream<SessionStatus> get statusChanges => _statusController.stream;

  @override
  Future<void> start() async {
    _emit(const SessionConnecting());
    _active[udid] = this;
    _inputBlocked = await _isInputShadowed();
    try {
      final result = (await _channel.invokeMapMethod<String, Object?>('start', {
        'udid': udid,
      }))!;
      textureId = result['textureId']! as int;
      setFrameCounter(this, _framesShown);
      chrome ??= await AppleChrome.load(
        _channel,
        udid,
      ).catchError((Object _) => null);
      final width = result['width']! as int;
      final height = result['height']! as int;
      if (width > 0 && height > 0) _live(width, height);
    } on PlatformException catch (e) {
      _active.remove(udid);
      _emit(SessionFailed(e.message ?? e.code));
    }
  }

  Future<int> _framesShown() async =>
      await _channel.invokeMethod<int>('frames', {'udid': udid}) ?? 0;

  Future<bool> _isInputShadowed() async {
    try {
      final result = await _simctlSpawn([
        'notifyutil',
        '-g',
        _deviceHubInputKey,
      ]);
      return result.stdout.trim() == '$_deviceHubInputKey 1';
    } catch (_) {
      return false;
    }
  }

  /// Resets the Device Hub flag, restarts backboardd (closes running apps)
  /// and reconnects the HID client.
  @override
  Future<void> repairInput() async {
    await _simctlSpawn(['notifyutil', '-s', _deviceHubInputKey, '0']);
    await _simctlSpawn([
      'launchctl',
      'kickstart',
      '-k',
      'system/com.apple.backboardd',
    ]);
    await _channel.invokeMethod<void>('stop', {'udid': udid});
    await Future<void>.delayed(const Duration(seconds: 2));
    await start();
  }

  Future<CommandResult> _simctlSpawn(List<String> args) => _exec.run(
    'xcrun',
    arguments: ['simctl', 'spawn', udid, ...args],
    timeout: const Duration(seconds: 10),
  );

  @override
  void touch(TouchPhase phase, double x, double y) {
    if (_width == null || _height == null) return;
    _channel.invokeMethod<void>('touch', {
      'udid': udid,
      'phase': phase.name,
      'x': x.clamp(0.0, 1.0),
      'y': y.clamp(0.0, 1.0),
    });
  }

  @override
  void press(DeviceButton button) {
    _channel.invokeMethod<void>('press', {'udid': udid, 'button': button.name});
  }

  @override
  bool get isRecording => _recorder.isRecording;

  @override
  Future<void> startRecording(String path) => _recorder.start(path);

  @override
  Future<String?> stopRecording() => _recorder.stop();

  @override
  Future<void> stop() async {
    await _recorder.stop();
    if (_active[udid] == this) _active.remove(udid);
    removeFrameCounter(this, _framesShown);
    await _channel.invokeMethod<void>('stop', {'udid': udid});
    await _statusController.close();
  }
}
