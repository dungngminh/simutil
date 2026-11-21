import 'package:flutter/services.dart';
import 'package:simutil_apple/simutil_apple.dart';
import 'package:simutil_core/simutil_core.dart';

/// Camera of an iOS simulator app: the native `SimCameraPlugin` (macOS)
/// renders a webcam, image or looping video into a shared feed per
/// simulator, and apps are launched with the serve-sim camera injector
/// reading it.
abstract final class SimCamera {
  static const _channel = MethodChannel('simutil/sim_camera');

  /// Simulators with a running feed; the host webcam stays on until stopped.
  static final _running = <String>{};

  /// Host cameras as (unique id, name).
  static Future<List<({String id, String name})>> webcams() async => [
    for (final cam in await _channel.invokeListMethod<Map>('webcams') ?? [])
      (id: cam['id'] as String, name: cam['name'] as String),
  ];

  /// The source feeding simulator [udid]: `webcam`, `image` or `video` and
  /// its webcam id / file path; null when no feed runs.
  static Future<({String source, String? arg})?> status(String udid) async {
    final reply = await _channel.invokeMapMethod<String, Object?>('status', {
      'udid': udid,
    });
    final source = reply?['source'];
    if (source is! String) return null;
    return (source: source, arg: reply!['arg'] as String?);
  }

  /// Feeds simulator [udid] from [source] (see [status]); a running feed
  /// switches without relaunching its apps.
  static Future<({String shm, String dylib})> setSource(
    String udid,
    String source, [
    String? arg,
  ]) async {
    try {
      final reply = (await _channel.invokeMapMethod<String, String>('start', {
        'udid': udid,
        'source': source,
        'arg': ?arg,
      }))!;
      _running.add(udid);
      return (shm: reply['shm']!, dylib: reply['dylib']!);
    } on PlatformException catch (e) {
      throw StateError(e.message ?? e.code);
    }
  }

  /// (Re)launches [appId] on simulator [device] reading its camera from
  /// [source], the running source when null (a webcam when none runs).
  static Future<void> launch(
    IosAutomation automation,
    Device device,
    String appId, {
    String? source,
    String? arg,
  }) async {
    final current = source == null ? await status(device.id) : null;
    final feed = await setSource(
      device.id,
      source ?? current?.source ?? 'webcam',
      source != null ? arg : current?.arg,
    );
    await automation.launchWithCamera(
      device,
      appId,
      dylib: feed.dylib,
      shmName: feed.shm,
    );
  }

  /// Stops simulator [udid]'s feed (a no-op without one); apps keep their
  /// last frame.
  static Future<void> stop(String udid) async {
    if (!_running.remove(udid)) return;
    await _channel.invokeMethod('stop', {'udid': udid});
  }

  /// Stops the feed of every simulator in [devices]' update that is no
  /// longer booted, so its webcam turns off with it.
  static void onDevices(List<Device> devices) {
    final booted = {
      for (final d in devices)
        if (d.state == DeviceState.booted) d.id,
    };
    _running.where((udid) => !booted.contains(udid)).toList().forEach(stop);
  }

  /// Parses an MCP / CLI camera value: `webcam`, `webcam:<id or name>`,
  /// `image:<path>` or `video:<path>`.
  static ({String source, String? arg}) parse(String value) {
    final colon = value.indexOf(':');
    final source = colon < 0 ? value : value.substring(0, colon);
    final arg = colon < 0 ? null : value.substring(colon + 1);
    if (!const {'webcam', 'image', 'video'}.contains(source) ||
        (source != 'webcam' && (arg == null || arg.isEmpty))) {
      throw FormatException(
        'camera must be webcam, webcam:<name>, image:<path> or video:<path>',
        value,
      );
    }
    return (source: source, arg: arg);
  }
}
