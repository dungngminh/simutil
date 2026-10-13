import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:simutil_core/simutil_core.dart';

import 'package:simutil_app/src/stream/ios/apple_chrome.dart';
import 'package:simutil_app/src/stream/stream_fps.dart';

/// View-only [DeviceSession] for an iPhone / iPad on USB, backed by the
/// native `DeviceStreamPlugin` (CoreMediaIO screen capture, macOS). Real
/// devices take no input without an XCUITest runner, so touches and buttons
/// do nothing.
class IosDeviceSession implements DeviceSession {
  /// Creates a session for device [udid] named [name] (the capture device is
  /// matched by name); call [start] to connect.
  IosDeviceSession(this.udid, {required this.name, required CommandExec exec})
    : _exec = exec {
    _ensureHandler();
  }

  /// devicectl identifier.
  final String udid;

  /// Device name, as the capture device reports it.
  final String name;
  final CommandExec _exec;

  static const _channel = MethodChannel('simutil/ios_device_stream');
  static final _active = <String, IosDeviceSession>{};
  static var _handlerSet = false;

  final _statusController = StreamController<SessionStatus>.broadcast();
  SessionStatus _status = const SessionConnecting();

  /// Texture id once [start] succeeded.
  int? textureId;

  /// Apple's frame for this device's model, when Xcode has a simulator of it.
  AppleChrome? chrome;

  static const _chromeChannel = MethodChannel('simutil/ios_stream');

  static void _ensureHandler() {
    if (_handlerSet) return;
    _handlerSet = true;
    _channel.setMethodCallHandler((call) async {
      final args = (call.arguments as Map).cast<String, Object?>();
      if (call.method == 'size') {
        _active[args['udid']]?._emit(
          SessionLive(
            width: args['width']! as int,
            height: args['height']! as int,
          ),
        );
      }
    });
  }

  void _emit(SessionStatus status) {
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  @override
  String get deviceId => udid;

  @override
  List<DeviceButton> get buttons => const [];

  @override
  SessionStatus get status => _status;

  @override
  Stream<SessionStatus> get statusChanges => _statusController.stream;

  @override
  Future<void> start() async {
    _emit(const SessionConnecting());
    _active[udid] = this;
    try {
      final result = (await _channel.invokeMapMethod<String, Object?>('start', {
        'udid': udid,
        'name': name,
      }))!;
      textureId = result['textureId']! as int;
      setFrameCounter(this, _framesShown);
      chrome ??= await _loadChrome().catchError((Object _) => null);
      // The first frame may have gone live before the frame was known.
      if (chrome != null && _status is SessionLive) _emit(_status);
      // Live once the first frame reports its size.
    } on PlatformException catch (e) {
      _active.remove(udid);
      _emit(SessionFailed(e.message ?? e.code));
    }
  }

  Future<AppleChrome?> _loadChrome() async {
    final model = await _productType();
    if (model == null) return null;
    return AppleChrome.load(_chromeChannel, udid, model: model);
  }

  /// Hardware model (`iPhone15,2`) from devicectl.
  Future<String?> _productType() async {
    final dir = await Directory.systemTemp.createTemp('simutil-device-');
    final file = File('${dir.path}/info.json');
    try {
      final result = await _exec.run(
        'xcrun',
        arguments: [
          'devicectl', 'device', 'info', 'details', //
          '--device', udid, '-q', '-j', file.path,
        ],
        timeout: const Duration(seconds: 20),
      );
      if (!result.success) return null;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      return switch (json) {
        {
          'result': {'hardwareProperties': {'productType': final String type}},
        } =>
          type,
        _ => null,
      };
    } finally {
      await dir.delete(recursive: true);
    }
  }

  Future<int> _framesShown() async =>
      await _channel.invokeMethod<int>('frames', {'udid': udid}) ?? 0;

  @override
  void touch(TouchPhase phase, double x, double y) {}

  @override
  void press(DeviceButton button) {}

  @override
  Future<void> repairInput() async {}

  /// The latest frame of streaming device [udid] as PNG.
  static Future<Uint8List> screenshot(String udid) async =>
      (await _channel.invokeMethod<Uint8List>('png', {'udid': udid}))!;

  String? _recording;

  @override
  bool get isRecording => _recording != null;

  /// Records video and audio as QuickTime (H.264 / AAC) into [path].
  @override
  Future<void> startRecording(String path) async {
    await _channel.invokeMethod<void>('record', {'udid': udid, 'path': path});
    _recording = path;
  }

  @override
  Future<String?> stopRecording() async {
    final path = _recording;
    if (path == null) return null;
    await _channel.invokeMethod<void>('stop_recording', {'udid': udid});
    _recording = null;
    return path;
  }

  @override
  Future<void> stop() async {
    await stopRecording();
    if (_active[udid] == this) _active.remove(udid);
    removeFrameCounter(this, _framesShown);
    await _channel.invokeMethod<void>('stop', {'udid': udid});
    await _statusController.close();
  }
}
