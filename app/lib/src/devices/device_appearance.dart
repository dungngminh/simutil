import 'package:simutil_core/simutil_core.dart';

/// Light / dark appearance of a running device: Android (emulators and
/// phones) through `cmd uimode night`, iOS simulators through
/// `simctl ui … appearance`. Physical iPhones have no interface for it.
abstract interface class DeviceAppearance {
  /// Uses [exec] for adb / xcrun; [adbPath] is read on each call (the SDK
  /// may be found later).
  factory DeviceAppearance(
    CommandExec exec, {
    required String Function() adbPath,
  }) = _DeviceAppearance;

  /// Whether [device] can switch appearance at all.
  static bool supports(Device device) =>
      device.state == DeviceState.booted &&
      (device.os == DeviceOs.android || !device.type.isPhysical);

  /// Whether [device] shows dark mode; null when it cannot tell (not
  /// supported, automatic / scheduled night mode, the command failed).
  Future<bool?> isDark(Device device);

  /// Switches [device] to dark or light mode; throws when it fails.
  Future<void> setDark(Device device, {required bool dark});
}

final class _DeviceAppearance implements DeviceAppearance {
  _DeviceAppearance(this._exec, {required String Function() adbPath})
    : _adbPath = adbPath;

  final CommandExec _exec;
  final String Function() _adbPath;

  /// Both answer in well under a second; a hung device must not hold up
  /// the context menu.
  static const _timeout = Duration(seconds: 5);

  @override
  Future<bool?> isDark(Device device) async {
    if (!DeviceAppearance.supports(device)) return null;
    try {
      final result = await _run(device);
      if (!result.success) return null;
      return parse(device.os, result.stdout);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setDark(Device device, {required bool dark}) async {
    if (!DeviceAppearance.supports(device)) {
      throw UnsupportedError('${device.name} cannot switch dark mode');
    }
    final result = await _run(
      device,
      device.os == DeviceOs.android
          ? (dark ? 'yes' : 'no')
          : (dark ? 'dark' : 'light'),
    );
    if (!result.success) {
      final why = result.stderr.trim();
      throw StateError(
        'Could not switch ${device.name} to ${dark ? 'dark' : 'light'} mode'
        '${why.isEmpty ? '' : ': $why'}',
      );
    }
  }

  /// Reads the mode, or sets it to [value] (the platform's own word).
  /// Reads (menu prefetches on hover) run in the background so they never
  /// take the slots kept for what the user just did.
  Future<CommandResult> _run(Device device, [String? value]) {
    final priority = value == null
        ? CommandPriority.background
        : CommandPriority.interactive;
    return device.os == DeviceOs.android
        ? _exec.run(
            _adbPath(),
            arguments: [
              '-s',
              device.id,
              'shell',
              'cmd',
              'uimode',
              'night',
              ?value,
            ],
            timeout: _timeout,
            priority: priority,
          )
        : _exec.run(
            'xcrun',
            arguments: ['simctl', 'ui', device.id, 'appearance', ?value],
            timeout: _timeout,
            priority: priority,
          );
  }

  /// `Night mode: yes|no|auto|custom` (Android) or `light|dark|…` (iOS).
  static bool? parse(DeviceOs os, String output) {
    final text = output.trim().toLowerCase();
    if (os == DeviceOs.android) {
      return switch (text.split(':').last.trim()) {
        'yes' => true,
        'no' => false,
        _ => null,
      };
    }
    return switch (text) {
      'dark' => true,
      'light' => false,
      _ => null,
    };
  }
}
