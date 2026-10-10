import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:simutil_core/simutil_core.dart';

import '../device_stream.dart';

/// Streams a booted iOS simulator through the native `SimStreamPlugin`
/// (macOS only): the framebuffer is a Flutter texture, input goes through
/// SimulatorKit's HID client.
class IosSimStream implements DeviceStream {
  IosSimStream(this.udid, {required CommandExec exec}) : _exec = exec {
    _ensureHandler();
  }

  final String udid;
  final CommandExec _exec;

  static const _channel = MethodChannel('simutil/ios_stream');
  static final _active = <String, IosSimStream>{};
  static var _handlerSet = false;

  /// Set by Xcode 27 Device Hub when it takes over input from the legacy
  /// HID path (see serve-sim `device-hub-input.ts`).
  static const _deviceHubInputKey = 'com.apple.coredevice.dtuhidd.active';

  int? _textureId;
  Size? _size;
  bool _inputBlocked = false;
  void Function(StreamStatus status)? _onStatus;

  static void _ensureHandler() {
    if (_handlerSet) return;
    _handlerSet = true;
    _channel.setMethodCallHandler((call) async {
      final args = (call.arguments as Map).cast<String, Object?>();
      final stream = _active[args['udid']];
      if (call.method == 'size' && stream != null) {
        stream._emitLive(
          Size(
            (args['width']! as int).toDouble(),
            (args['height']! as int).toDouble(),
          ),
        );
      }
    });
  }

  void _emitLive(Size size) {
    _size = size;
    _onStatus?.call(StreamLive(size, inputBlocked: _inputBlocked));
  }

  @override
  List<DeviceButton> get buttons => const [
    DeviceButton.home,
    DeviceButton.recents,
    DeviceButton.lock,
  ];

  @override
  Future<void> start(void Function(StreamStatus status) onStatus) async {
    onStatus(const StreamConnecting());
    _onStatus = onStatus;
    _active[udid] = this;
    _inputBlocked = await _isInputShadowed();
    try {
      final result = (await _channel.invokeMapMethod<String, Object?>('start', {
        'udid': udid,
      }))!;
      _textureId = result['textureId']! as int;
      final width = result['width']! as int;
      final height = result['height']! as int;
      if (width > 0 && height > 0) {
        _emitLive(Size(width.toDouble(), height.toDouble()));
      }
    } on PlatformException catch (e) {
      _active.remove(udid);
      onStatus(StreamFailed(e.message ?? e.code));
    }
  }

  Future<bool> _isInputShadowed() async {
    try {
      final result = await _simctlSpawn([
        'notifyutil',
        '-g',
        _deviceHubInputKey,
      ]);
      return result.stdout.trim() == '$_deviceHubInputKey 1';
    } catch (_) {
      return false; // older runtimes do not publish this state
    }
  }

  /// Resets the Device Hub flag, then restarts backboardd (which closes
  /// running apps) and reconnects the HID client.
  @override
  Future<void> repairInput() async {
    await _simctlSpawn(['notifyutil', '-s', _deviceHubInputKey, '0']);
    await _simctlSpawn([
      'launchctl',
      'kickstart',
      '-k',
      'system/com.apple.backboardd',
    ]);
    final onStatus = _onStatus;
    if (onStatus == null) return;
    await _channel.invokeMethod<void>('stop', {'udid': udid});
    await Future<void>.delayed(const Duration(seconds: 2));
    await start(onStatus);
  }

  Future<CommandResult> _simctlSpawn(List<String> args) => _exec.run(
    'xcrun',
    arguments: ['simctl', 'spawn', udid, ...args],
    timeout: const Duration(seconds: 10),
  );

  @override
  Future<void> stop() async {
    _onStatus = null;
    if (_active[udid] == this) _active.remove(udid);
    await _channel.invokeMethod<void>('stop', {'udid': udid});
  }

  @override
  Widget buildView() => switch (_textureId) {
    final id? => Texture(textureId: id, filterQuality: FilterQuality.medium),
    null => const SizedBox.shrink(),
  };

  @override
  void touch(TouchPhase phase, Offset position) {
    if (_size == null) return;
    _channel.invokeMethod<void>('touch', {
      'udid': udid,
      'phase': phase.name,
      'x': position.dx.clamp(0.0, 1.0),
      'y': position.dy.clamp(0.0, 1.0),
    });
  }

  @override
  void press(DeviceButton button) {
    _channel.invokeMethod<void>('press', {'udid': udid, 'button': button.name});
  }
}
