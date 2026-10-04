import 'dart:convert';
import 'dart:io';

import 'package:simutil_shared/src/app_state.dart';

/// GitHub releases page, shown when no upgrade command fits.
const simutilReleasesUrl = 'https://github.com/dungngminh/simutil/releases';

/// How the running `simutil` was installed.
enum InstallSource {
  /// `brew install simutil` from the `dungngminh/simutil` tap.
  homebrew('brew upgrade dungngminh/simutil/simutil'),

  /// `dart pub global activate simutil` from pub.dev.
  pub('dart pub global activate simutil'),

  /// `install.sh` (binary in `~/.local/lib/simutil`).
  installScript(
    'curl -fsSL https://raw.githubusercontent.com/dungngminh/simutil/main/install.sh | bash',
  ),

  /// `install.ps1` (binary in `%LOCALAPPDATA%\simutil`).
  powershell(
    'powershell -ExecutionPolicy Bypass -Command "iwr -useb https://raw.githubusercontent.com/dungngminh/simutil/main/install.ps1 | iex"',
  ),

  /// Run from a source checkout.
  source(null),

  /// Anything else, e.g. a binary copied from a release archive.
  unknown(null);

  const InstallSource(this.upgradeCommand);

  /// Shell command that upgrades this install, or `null` when none applies.
  final String? upgradeCommand;
}

/// Detects the install channel from the running [executable] (symlinks
/// resolved) and [script] (`Platform.script` path).
///
/// Script is checked first: pub installs run through the `dart` binary,
/// which itself may live in a Homebrew Cellar.
InstallSource detectInstallSource({
  required String executable,
  required String script,
}) {
  final scriptPath = script.replaceAll(r'\', '/').toLowerCase();
  final exePath = executable.replaceAll(r'\', '/').toLowerCase();
  if (scriptPath.contains('/global_packages/simutil/')) {
    return InstallSource.pub;
  }
  if (scriptPath.endsWith('.dart')) return InstallSource.source;
  if (exePath.contains('/cellar/simutil/')) return InstallSource.homebrew;
  if (exePath.contains('/.local/lib/simutil/')) {
    return InstallSource.installScript;
  }
  if (exePath.contains('/appdata/local/simutil/')) {
    return InstallSource.powershell;
  }
  return InstallSource.unknown;
}

/// [detectInstallSource] for the current process.
InstallSource currentInstallSource() {
  var executable = Platform.resolvedExecutable;
  try {
    executable = File(executable).resolveSymbolicLinksSync();
  } catch (_) {}
  return detectInstallSource(
    executable: executable,
    script: Platform.script.toFilePath(),
  );
}

final _semver = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$');

/// Whether [latest] is a higher `major.minor.patch` than [current].
///
/// Pre-release or malformed versions on either side return `false`.
bool isNewerVersion(String latest, String current) {
  final a = _semver.firstMatch(latest.trim());
  final b = _semver.firstMatch(current.trim());
  if (a == null || b == null) return false;
  for (var i = 1; i <= 3; i++) {
    final diff = int.parse(a[i]!) - int.parse(b[i]!);
    if (diff != 0) return diff > 0;
  }
  return false;
}

/// A newer release and how to install it.
class UpdateInfo {
  /// Creates update info for [latestVersion] installed via [source].
  const UpdateInfo({required this.latestVersion, required this.source});

  /// Newest released version, without a `v` prefix.
  final String latestVersion;

  /// Channel the running binary was installed from.
  final InstallSource source;

  /// Upgrade command, or the releases URL when none applies.
  String get instruction => source.upgradeCommand ?? simutilReleasesUrl;
}

/// Fetches [uri] and returns the body, or `null` on any non-200 response.
typedef HttpGet = Future<String?> Function(Uri uri);

/// Checks for a newer `simutil` release, at most once per [interval].
abstract interface class UpdateChecker {
  /// [source] picks the feed: pub.dev for pub installs, GitHub releases
  /// otherwise (Homebrew and install scripts follow published releases).
  /// Skipped when `SIMUTIL_NO_UPDATE_CHECK` or `CI` is set in [environment].
  factory UpdateChecker({
    required AppStateService appState,
    InstallSource? source,
    HttpGet? httpGet,
    Map<String, String>? environment,
    DateTime Function()? now,
    Duration interval,
  }) = _UpdateChecker;

  /// Returns the newer release, or `null` when up to date, disabled, or
  /// offline. [force] skips the opt-out env and cache. Never throws.
  Future<UpdateInfo?> check(String currentVersion, {bool force = false});
}

final class _UpdateChecker implements UpdateChecker {
  _UpdateChecker({
    required AppStateService appState,
    InstallSource? source,
    HttpGet? httpGet,
    Map<String, String>? environment,
    DateTime Function()? now,
    this.interval = const Duration(hours: 24),
  }) : _appState = appState,
       _source = source,
       _httpGet = httpGet ?? _defaultHttpGet,
       _environment = environment ?? Platform.environment,
       _now = now ?? DateTime.now;

  final AppStateService _appState;
  final InstallSource? _source;
  final HttpGet _httpGet;
  final Map<String, String> _environment;
  final DateTime Function() _now;
  final Duration interval;

  @override
  Future<UpdateInfo?> check(String currentVersion, {bool force = false}) async {
    try {
      if (!force &&
          (_environment.containsKey('SIMUTIL_NO_UPDATE_CHECK') ||
              _environment.containsKey('CI'))) {
        return null;
      }
      final source = _source ?? currentInstallSource();
      final state = await _appState.load();
      var latest = state.latestKnownVersion;
      final last = state.lastUpdateCheck;
      final now = _now();
      if (force || last == null || now.difference(last) >= interval) {
        latest = await _fetchLatest(source) ?? latest;
        // Stamp even on failure so offline users aren't re-queried each run.
        await _appState.update(
          (s) => s.copyWith(lastUpdateCheck: now, latestKnownVersion: latest),
        );
      }
      if (latest == null || !isNewerVersion(latest, currentVersion)) {
        return null;
      }
      return UpdateInfo(latestVersion: latest, source: source);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _fetchLatest(InstallSource source) async {
    try {
      if (source == InstallSource.pub) {
        final body = await _httpGet(
          Uri.parse('https://pub.dev/api/packages/simutil'),
        );
        if (body == null) return null;
        final json = jsonDecode(body) as Map<String, dynamic>;
        return (json['latest'] as Map<String, dynamic>)['version'] as String;
      }
      final body = await _httpGet(
        Uri.parse(
          'https://api.github.com/repos/dungngminh/simutil/releases/latest',
        ),
      );
      if (body == null) return null;
      final json = jsonDecode(body) as Map<String, dynamic>;
      final tag = json['tag_name'] as String;
      return tag.startsWith('v') ? tag.substring(1) : tag;
    } catch (_) {
      return null;
    }
  }
}

Future<String?> _defaultHttpGet(Uri uri) async {
  const timeout = Duration(seconds: 3);
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.getUrl(uri).timeout(timeout);
    // GitHub's API rejects requests without a User-Agent.
    request.headers
      ..set(HttpHeaders.userAgentHeader, 'simutil')
      ..set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(timeout);
    if (response.statusCode != HttpStatus.ok) return null;
    return await response.transform(utf8.decoder).join().timeout(timeout);
  } finally {
    client.close(force: true);
  }
}
