import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// `~/.simutil/desktop-settings.json`, next to the CLI's files but in its
/// own file so the CLI's `settings.yaml` / `state.json` schemas stay
/// untouched.
String resolveDesktopSettingsPath() {
  final home =
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '.';
  final sep = Platform.pathSeparator;
  return '$home$sep.simutil${sep}desktop-settings.json';
}

/// The app's persisted settings: one JSON object with a section per cubit.
abstract interface class DesktopSettingsStore {
  /// File-backed store; [path] defaults to [resolveDesktopSettingsPath].
  /// A [readOnly] store keeps writes in memory, so a device window never
  /// overwrites the main window's newer settings with its stale copy.
  factory DesktopSettingsStore({String? path, bool readOnly}) =
      _FileDesktopSettingsStore;

  /// Reads the file. A missing or unreadable file leaves every section
  /// empty, so cubits start from their defaults; an unreadable one is
  /// copied to `<path>.bak` first, since the next save replaces it.
  Future<void> load();

  /// The stored value of [key], `null` when absent.
  Object? section(String key);

  /// Replaces [key] and saves the file in the background.
  void write(String key, Object? value);

  /// Completes once every pending save is on disk.
  Future<void> flush();
}

final class _FileDesktopSettingsStore implements DesktopSettingsStore {
  _FileDesktopSettingsStore({String? path, this.readOnly = false})
    : _path = path ?? resolveDesktopSettingsPath();

  final String _path;
  final bool readOnly;
  Map<String, Object?> _data = {};
  Future<void> _pending = Future.value();

  @override
  Future<void> load() async {
    final file = File(_path);
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, Object?>) {
        _data = decoded;
        return;
      }
    } on PathNotFoundException {
      _data = {};
      return;
    } catch (_) {
      // Unreadable or not JSON (e.g. hand-edited): handled below.
    }
    _data = {};
    // The next write saves only its own section and would drop the rest.
    if (readOnly) return;
    try {
      await file.copy('$_path.bak');
      debugPrint('Settings unreadable; kept a copy at $_path.bak');
    } catch (e) {
      debugPrint('Settings unreadable and not backed up: $e');
    }
  }

  @override
  Object? section(String key) => _data[key];

  @override
  void write(String key, Object? value) {
    _data = {..._data, key: value};
    if (readOnly) return;
    final snapshot = jsonEncode(_data);
    // Chained so an older snapshot never lands after a newer one.
    _pending = _pending.then((_) => _save(snapshot));
  }

  Future<void> _save(String json) async {
    try {
      final file = File(_path);
      await file.parent.create(recursive: true);
      // Write then rename: quitting mid-save never leaves half a file.
      final tmp = File('$_path.tmp');
      await tmp.writeAsString(json, flush: true);
      await tmp.rename(_path);
    } catch (e) {
      debugPrint('Saving settings failed: $e');
    }
  }

  @override
  Future<void> flush() => _pending;
}

/// [map]'s value of [key] when it has type [T], else `null`.
T? readField<T>(Object? map, String key) {
  if (map is! Map) return null;
  final value = map[key];
  return value is T ? value : null;
}

/// The value of [values] named [name], else `null`.
T? enumByName<T extends Enum>(List<T> values, Object? name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
