import 'dart:io';

import 'package:simutil/services/command_exec.dart';
import 'package:simutil/utils/int_extension.dart';

/// Result of clearing Xcode Derived Data.
class XcodeCacheClearResult {
  const XcodeCacheClearResult({
    required this.success,
    required this.message,
    this.freedBytes,
  });

  final bool success;
  final String message;
  final int? freedBytes;
}

/// Manages Xcode Derived Data at `~/Library/Developer/Xcode/DerivedData`.
///
/// All shell work goes through [CommandExec] so the TUI isolate stays free.
/// Public APIs that touch the filesystem are macOS-only.
class XcodeCacheService {
  XcodeCacheService(this._exec, {String? homeDirectory})
    : _homeDirectory = homeDirectory;

  final CommandExec _exec;
  final String? _homeDirectory;

  /// Absolute path to Derived Data for [home].
  static String derivedDataPathFor(String home) =>
      '$home/Library/Developer/Xcode/DerivedData';

  /// Default Derived Data path under the current user home.
  ///
  /// Returns `null` when neither [homeDirectory] nor `$HOME` is available.
  String? get derivedDataPath {
    final home = _homeDirectory ?? Platform.environment['HOME'];
    if (home == null || home.isEmpty) return null;
    return derivedDataPathFor(home);
  }

  /// Disk usage of Derived Data in bytes, or `null` if missing / unreadable.
  Future<int?> getDerivedDataSizeBytes() async {
    if (!Platform.isMacOS) return null;
    final path = derivedDataPath;
    if (path == null) return null;
    try {
      final result = await _exec.run('du', arguments: ['-sk', path]);
      if (!result.success) return null;
      final line = result.stdout.trim();
      if (line.isEmpty) return null;
      final kbToken = line.split(RegExp(r'\s+')).first;
      final kb = int.tryParse(kbToken);
      if (kb == null) return null;
      return kb * 1024;
    } catch (_) {
      return null;
    }
  }

  /// Deletes Derived Data and recreates an empty directory.
  ///
  /// When the folder is already missing, returns success with a soft message.
  Future<XcodeCacheClearResult> clearDerivedData() async {
    if (!Platform.isMacOS) {
      return const XcodeCacheClearResult(
        success: false,
        message: 'Xcode Derived Data is only available on macOS',
      );
    }

    final path = derivedDataPath;
    if (path == null) {
      return const XcodeCacheClearResult(
        success: false,
        message:
            'Home directory is unavailable (set HOME or pass homeDirectory)',
      );
    }

    final sizeBefore = await getDerivedDataSizeBytes();

    try {
      final rm = await _exec.run('rm', arguments: ['-rf', path]);
      if (!rm.success) {
        final detail = rm.stderr.trim().isNotEmpty
            ? rm.stderr.trim()
            : 'rm failed (exit ${rm.exitCode})';
        return XcodeCacheClearResult(
          success: false,
          message: 'Failed to clear Derived Data: $detail',
          freedBytes: sizeBefore,
        );
      }

      final mkdir = await _exec.run('mkdir', arguments: ['-p', path]);
      if (!mkdir.success) {
        final detail = mkdir.stderr.trim().isNotEmpty
            ? mkdir.stderr.trim()
            : 'mkdir failed (exit ${mkdir.exitCode})';
        return XcodeCacheClearResult(
          success: false,
          message:
              'Derived Data was removed but the folder could not be recreated: $detail',
          freedBytes: sizeBefore,
        );
      }

      if (sizeBefore == null || sizeBefore == 0) {
        return const XcodeCacheClearResult(
          success: true,
          message: 'Derived Data was already empty or missing',
          freedBytes: 0,
        );
      }

      return XcodeCacheClearResult(
        success: true,
        message: 'Cleared ${sizeBefore.formatBytes} of Derived Data',
        freedBytes: sizeBefore,
      );
    } catch (e) {
      return XcodeCacheClearResult(
        success: false,
        message: 'Failed to clear Derived Data: $e',
        freedBytes: sizeBefore,
      );
    }
  }
}
