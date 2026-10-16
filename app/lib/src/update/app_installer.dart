import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:simutil_app/src/update/app_update_cubit.dart';
import 'package:simutil_core/simutil_core.dart';

/// How the running app was installed, which decides how it updates.
enum UpdateChannel {
  /// `brew install --cask simutil-desktop`: `brew upgrade` replaces it.
  homebrew,

  /// Copied from the DMG: the new bundle is swapped in place.
  dmg,

  /// Inno Setup installer (direct or winget): the new one runs silently.
  windowsInstaller,

  /// AppImage: the file is replaced.
  appImage,

  /// Debug builds and unknown installs: open the release page.
  manual,
}

const _caskrooms = [
  '/opt/homebrew/Caskroom/simutil-desktop',
  '/usr/local/Caskroom/simutil-desktop',
];

/// The `.app` bundle holding [executable], or `null` outside one.
String? appBundleOf(String executable) {
  final i = executable.indexOf('.app/');
  return i < 0 ? null : executable.substring(0, i + 4);
}

/// Picks the update channel from where the app runs.
UpdateChannel detectUpdateChannel({
  required String os,
  required String executable,
  required Map<String, String> environment,
  required bool Function(String path) dirExists,
  bool releaseBuild = kReleaseMode,
}) {
  if (!releaseBuild) return UpdateChannel.manual;
  return switch (os) {
    'macos' when appBundleOf(executable) == null => UpdateChannel.manual,
    'macos' when _caskrooms.any(dirExists) => UpdateChannel.homebrew,
    'macos' => UpdateChannel.dmg,
    'windows' => UpdateChannel.windowsInstaller,
    'linux' when environment['APPIMAGE'] != null => UpdateChannel.appImage,
    _ => UpdateChannel.manual,
  };
}

/// The SHA-256 of [file] listed in a release's `checksums.txt` ([body]).
String? checksumFor(String body, String file) {
  for (final line in body.split('\n')) {
    final parts = line.trim().split(RegExp(r'\s+\*?'));
    if (parts.length == 2 && parts[1] == file) return parts[0].toLowerCase();
  }
  return null;
}

/// One step of an in-place update, for the progress toast.
final class UpdateProgress {
  const UpdateProgress(this.step, [this.fraction]);

  /// What is happening, e.g. "Downloading 12.3 / 54.4 MB".
  final String step;

  /// 0..1, or `null` when the step can't measure it.
  final double? fraction;
}

/// Updates the running app in place through its [UpdateChannel], then
/// quits and relaunches it.
abstract interface class AppInstaller {
  factory AppInstaller(
    CommandExec exec, {
    required Future<void> Function() quit,
  }) = _AppInstaller;

  UpdateChannel get channel;

  /// Installs [update]; on success the app quits and the new version
  /// starts. Throws when anything fails before quitting, leaving the
  /// current install untouched.
  Future<void> install(
    AppUpdate update, {
    void Function(UpdateProgress)? onProgress,
  });
}

final class _AppInstaller implements AppInstaller {
  _AppInstaller(this._exec, {required Future<void> Function() quit})
    : _quit = quit;

  final CommandExec _exec;
  final Future<void> Function() _quit;
  void Function(UpdateProgress) _progress = (_) {};

  @override
  late final UpdateChannel channel = detectUpdateChannel(
    os: Platform.operatingSystem,
    executable: Platform.resolvedExecutable,
    environment: Platform.environment,
    dirExists: (path) => Directory(path).existsSync(),
  );

  @override
  Future<void> install(
    AppUpdate update, {
    void Function(UpdateProgress)? onProgress,
  }) async {
    _progress = onProgress ?? (_) {};
    switch (channel) {
      case UpdateChannel.homebrew:
        await _brewUpgrade();
      case UpdateChannel.dmg:
        await _swapBundle(update);
      case UpdateChannel.windowsInstaller:
        await _runInstaller(update);
      case UpdateChannel.appImage:
        await _replaceAppImage(update);
      case UpdateChannel.manual:
        throw StateError('No in-place update for this install');
    }
  }

  Future<void> _brewUpgrade() async {
    final bundle = appBundleOf(Platform.resolvedExecutable)!;
    final brew = [
      '/opt/homebrew/bin/brew',
      '/usr/local/bin/brew',
    ].firstWhere((p) => File(p).existsSync());
    _progress(const UpdateProgress('Upgrading with Homebrew…'));
    final result = await _exec.run(
      brew,
      arguments: ['upgrade', '--cask', 'simutil-desktop'],
      timeout: const Duration(minutes: 10),
    );
    _check(result, 'brew upgrade');
    await _relaunch(['open', bundle]);
  }

  /// Copies the new bundle next to the old one while still running, so a
  /// failure (download, checksum, no write access) changes nothing; the
  /// relaunch script then only renames.
  Future<void> _swapBundle(AppUpdate update) async {
    final bundle = appBundleOf(Platform.resolvedExecutable)!;
    final dir = await Directory.systemTemp.createTemp('simutil-update');
    final dmg = await _download(update, 'SimUtil-macos.dmg', dir);
    final mount = '${dir.path}/mnt';
    await Directory(mount).create();
    _check(
      await _exec.run(
        'hdiutil',
        arguments: [
          'attach',
          '-nobrowse',
          '-readonly',
          '-mountpoint',
          mount,
          dmg.path,
        ],
      ),
      'hdiutil attach',
    );
    _progress(const UpdateProgress('Installing…'));
    try {
      final stale = Directory('$bundle.new');
      if (stale.existsSync()) await stale.delete(recursive: true);
      _check(
        await _exec.run(
          'ditto',
          arguments: ['$mount/SimUtil.app', '$bundle.new'],
        ),
        'copy new app',
      );
    } finally {
      await _exec.run('hdiutil', arguments: ['detach', mount, '-force']);
    }
    await _relaunch([
      '/bin/sh',
      '-c',
      r'mv "$1" "$1.old" && mv "$1.new" "$1"; rm -rf "$1.old" "$2"; open "$1"',
      'sh',
      bundle,
      dir.path,
    ]);
  }

  Future<void> _runInstaller(AppUpdate update) async {
    final dir = await Directory.systemTemp.createTemp('simutil-update');
    final setup = await _download(update, 'SimUtil-windows-x64-setup.exe', dir);
    String quote(String s) => "'${s.replaceAll("'", "''")}'";
    // The installer replaces files only once this process is gone.
    await Process.start('powershell', [
      '-NoProfile',
      '-Command',
      'Wait-Process -Id $pid -ErrorAction SilentlyContinue; '
          'Start-Process -Wait -FilePath ${quote(setup.path)} '
          "-ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART'; "
          'Start-Process -FilePath ${quote(Platform.resolvedExecutable)}',
    ], mode: ProcessStartMode.detached);
    _progress(const UpdateProgress('Restarting…', 1));
    await _quit();
  }

  /// Linux lets a running AppImage be renamed over.
  Future<void> _replaceAppImage(AppUpdate update) async {
    final appImage = Platform.environment['APPIMAGE']!;
    final file = await _download(
      update,
      'SimUtil-linux-x86_64.AppImage',
      File(appImage).parent,
      saveAs: '${File(appImage).uri.pathSegments.last}.part',
    );
    _progress(const UpdateProgress('Installing…'));
    _check(await _exec.run('chmod', arguments: ['+x', file.path]), 'chmod');
    await file.rename(appImage);
    await _relaunch([appImage]);
  }

  /// Downloads [asset] of [update] into [dir] and checks it against the
  /// release's `checksums.txt`.
  Future<File> _download(
    AppUpdate update,
    String asset,
    Directory dir, {
    String? saveAs,
  }) async {
    final base =
        'https://github.com/dungngminh/simutil/releases/download/app-v${update.version}';
    final file = File('${dir.path}/${saveAs ?? asset}');
    final expected = checksumFor(
      await _get(
        Uri.parse('$base/checksums.txt'),
        (response) => utf8.decodeStream(response),
      ),
      asset,
    );
    if (expected == null) throw StateError('No checksum for $asset');
    await _get(Uri.parse('$base/$asset'), (response) async {
      final total = response.contentLength;
      final sink = file.openWrite();
      var received = 0;
      var reported = -1;
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          // One update per percent, not per chunk.
          final percent = total > 0 ? received * 100 ~/ total : -1;
          if (percent == reported && total > 0) continue;
          reported = percent;
          _progress(
            UpdateProgress(
              total > 0
                  ? 'Downloading ${_mb(received)} / ${_mb(total)} MB'
                  : 'Downloading ${_mb(received)} MB',
              total > 0 ? received / total : null,
            ),
          );
        }
      } finally {
        await sink.close();
      }
    });
    _progress(const UpdateProgress('Verifying download…'));
    final actual = (await sha256.bind(file.openRead()).first).toString();
    if (actual != expected) {
      await file.delete();
      throw StateError('Checksum mismatch for $asset');
    }
    return file;
  }

  /// GETs [uri] (following GitHub's redirect to the asset host) and hands
  /// the body to [read].
  Future<T> _get<T>(
    Uri uri,
    Future<T> Function(HttpClientResponse) read,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..userAgent = 'simutil-desktop';
    try {
      final response = await (await client.getUrl(uri)).close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      return await read(response);
    } finally {
      client.close(force: true);
    }
  }

  static String _mb(int bytes) => (bytes / 1e6).toStringAsFixed(1);

  /// Runs [command] detached once this process has exited, then quits.
  Future<void> _relaunch(List<String> command) async {
    _progress(const UpdateProgress('Restarting…', 1));
    await Process.start('/bin/sh', [
      '-c',
      r'while kill -0 "$1" 2>/dev/null; do sleep 0.2; done; shift; exec "$@"',
      'sh',
      '$pid',
      ...command,
    ], mode: ProcessStartMode.detached);
    await _quit();
  }

  void _check(CommandResult result, String step) {
    if (!result.success) {
      throw StateError('$step failed: ${result.stderr.trim()}');
    }
  }
}
