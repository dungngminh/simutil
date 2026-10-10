import 'dart:io';

import 'package:simutil_apple/src/slim/slim_categories.dart';
import 'package:simutil_core/simutil_core.dart';

/// Disables background daemons in an iOS simulator to cut its memory use
/// (about 4 GB to 1 GB), so many simulators can run at once.
///
/// Mechanism from simslim (MIT): launchd_sim reads per-device disable
/// overrides from a host plist at boot, so the device is shut down, the
/// store is rewritten, and the device is booted again. Needs iOS/tvOS 18.5+,
/// watchOS 11.5+ or visionOS 2.5+ for the overrides to persist.
abstract interface class SimulatorSlimmer {
  /// Creates a slimmer; [storeRoot] is a test seam for the host store.
  factory SimulatorSlimmer(CommandExec exec, {String storeRoot}) =
      _SimulatorSlimmer;

  /// Whether any managed daemon is disabled for [udid].
  Future<bool> isSlim(String udid);

  /// Disables every category except [except] (category ids), rebooting
  /// the simulator when it is booted.
  Future<void> slim(String udid, {Set<String> except = const {}});

  /// Re-enables every managed daemon, rebooting when booted.
  Future<void> unslim(String udid);
}

class _SimulatorSlimmer implements SimulatorSlimmer {
  _SimulatorSlimmer(this._exec, {this.storeRoot = '/private/var/tmp'});

  final CommandExec _exec;
  final String storeRoot;

  static final _entry = RegExp(r'<key>([^<]+)</key>\s*<(true|false)/>');

  static final Set<String> _managed = {
    for (final c in slimCategories) ...c.labels,
    for (final c in slimCategories) ...c.alwaysEnabled,
  };

  File _store(String udid) =>
      File('$storeRoot/com.apple.CoreSimulator.SimDevice.$udid/disabled.plist');

  Map<String, bool> _read(String udid) {
    final file = _store(udid);
    if (!file.existsSync()) return {};
    return {
      for (final m in _entry.allMatches(file.readAsStringSync()))
        _unescape(m.group(1)!): m.group(2) == 'true',
    };
  }

  /// Merges into the store, keeping entries launchd_sim wrote itself;
  /// written atomically so launchd_sim never reads a partial file.
  void _write(String udid, Map<String, bool> changes) {
    final entries = {..._read(udid), ...changes};
    final file = _store(udid);
    file.parent.createSync(recursive: true);
    final labels = entries.keys.toList()..sort();
    final xml = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
        '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">',
      )
      ..writeln('<plist version="1.0">')
      ..writeln('<dict>');
    for (final label in labels) {
      xml
        ..writeln('\t<key>${_escape(label)}</key>')
        ..writeln('\t<${entries[label]! ? 'true' : 'false'}/>');
    }
    xml
      ..writeln('</dict>')
      ..writeln('</plist>');
    File('${file.path}.tmp')
      ..writeAsStringSync(xml.toString())
      ..renameSync(file.path);
  }

  @override
  Future<bool> isSlim(String udid) async =>
      _read(udid).entries.any((e) => e.value && _managed.contains(e.key));

  @override
  Future<void> slim(String udid, {Set<String> except = const {}}) async {
    final kept = {
      for (final c in slimCategories)
        if (except.contains(c.id)) ...c.labels,
      for (final c in slimCategories) ...c.alwaysEnabled,
    };
    await _apply(udid, {
      for (final label in _managed) label: !kept.contains(label),
    });
  }

  @override
  Future<void> unslim(String udid) =>
      _apply(udid, {for (final label in _managed) label: false});

  Future<void> _apply(String udid, Map<String, bool> changes) async {
    final booted = await _isBooted(udid);
    if (booted) {
      await _simctl(['shutdown', udid]);
    }
    _write(udid, changes);
    if (booted) {
      await _simctl(['boot', udid]);
    }
  }

  Future<bool> _isBooted(String udid) async {
    final result = await _simctl(['list', 'devices', udid]);
    return result.stdout.contains('(Booted)');
  }

  Future<CommandResult> _simctl(List<String> args) async {
    final result = await _exec.run(
      'xcrun',
      arguments: ['simctl', ...args],
      timeout: const Duration(minutes: 2),
    );
    if (!result.success) {
      throw StateError('simctl ${args.first} failed: ${result.stderr.trim()}');
    }
    return result;
  }

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static String _unescape(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
}
