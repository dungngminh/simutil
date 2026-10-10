import 'dart:io';

import 'package:simutil_core/simutil_core.dart';

/// The user's scrcpy install: the server jar and the version it expects.
class ScrcpyInstall {
  /// Creates an install record.
  const ScrcpyInstall({required this.serverPath, required this.version});

  /// `scrcpy-server` file pushed to the device.
  final String serverPath;

  /// Version string the server checks, e.g. `4.0`.
  final String version;

  /// Shown when no usable install is found.
  static const installHint =
      'scrcpy not found. Install it (brew install scrcpy / scoop install '
      'scrcpy / apt install scrcpy) or set SCRCPY_SERVER_PATH.';

  static final _versionPattern = RegExp(r'scrcpy v?(\d+\.\d+(?:\.\d+)?)');

  /// Finds scrcpy via `SCRCPY_SERVER_PATH` or the `scrcpy` binary location.
  /// GUI apps on macOS do not inherit the shell PATH, so Homebrew prefixes
  /// are probed directly.
  static Future<ScrcpyInstall?> locate(
    CommandExec exec, {
    Map<String, String>? environment,
  }) async {
    final env = environment ?? Platform.environment;
    for (final binary in _binaryCandidates(env)) {
      final CommandResult result;
      try {
        result = await exec.run(binary, arguments: ['--version']);
      } catch (_) {
        continue;
      }
      final version = _versionPattern.firstMatch(result.stdout)?.group(1);
      if (!result.success || version == null) continue;

      final server =
          env['SCRCPY_SERVER_PATH'] ?? await _serverNextTo(exec, binary);
      if (server != null && File(server).existsSync()) {
        return ScrcpyInstall(serverPath: server, version: version);
      }
    }
    return null;
  }

  static List<String> _binaryCandidates(Map<String, String> env) => [
    ?env['SCRCPY'],
    if (Platform.isMacOS) ...[
      '/opt/homebrew/bin/scrcpy',
      '/usr/local/bin/scrcpy',
    ],
    if (Platform.isLinux) ...[
      '/usr/bin/scrcpy',
      '/usr/local/bin/scrcpy',
      '/snap/bin/scrcpy',
    ],
    'scrcpy',
  ];

  /// `<prefix>/bin/scrcpy` ships `<prefix>/share/scrcpy/scrcpy-server`;
  /// the Windows zip keeps `scrcpy-server` beside `scrcpy.exe`.
  static Future<String?> _serverNextTo(CommandExec exec, String binary) async {
    var path = binary;
    if (!path.contains(Platform.pathSeparator) && !path.contains('/')) {
      final which = await exec.run(
        Platform.isWindows ? 'where' : 'which',
        arguments: [binary],
      );
      if (!which.success) return null;
      path = which.stdout.split('\n').first.trim();
    }
    final dir = File(File(path).resolveSymbolicLinksSync()).parent;
    final candidates = [
      '${dir.path}/scrcpy-server',
      '${dir.parent.path}/share/scrcpy/scrcpy-server',
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }
}
