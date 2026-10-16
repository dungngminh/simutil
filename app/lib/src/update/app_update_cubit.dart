import 'dart:convert';
import 'dart:io';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:equatable/equatable.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:simutil_shared/simutil_shared.dart';

/// The running app's `X.Y.Z`: `version:` in `app/pubspec.yaml`, or
/// `--build-name` when given, as baked into the bundle (Info.plist, the
/// .exe version resource, `version.json` on Linux).
Future<String> getAppVersion() async =>
    (await PackageInfo.fromPlatform()).version;

const _releasesUrl =
    'https://api.github.com/repos/dungngminh/simutil/releases?per_page=30';

/// A published desktop release newer than the running app.
final class AppUpdate extends Equatable {
  const AppUpdate({required this.version, required this.url});

  final String version;

  /// The GitHub release page with the installers.
  final String url;

  @override
  List<Object?> get props => [version, url];
}

/// The newest published `app-vX.Y.Z` release in a GitHub releases list
/// ([json]), if newer than [current]. CLI releases (`v*`) share the repo,
/// so `/releases/latest` can't be used.
AppUpdate? newerAppRelease(String json, String current) {
  for (final release in jsonDecode(json) as List<dynamic>) {
    final r = release as Map<String, dynamic>;
    final tag = r['tag_name'] as String? ?? '';
    if (!tag.startsWith('app-v') ||
        r['draft'] == true ||
        r['prerelease'] == true) {
      continue;
    }
    final version = tag.substring('app-v'.length);
    // The list is newest first: the first app release decides.
    if (!isNewerVersion(version, current)) return null;
    return AppUpdate(version: version, url: r['html_url'] as String);
  }
  return null;
}

/// Records [current] as the last run version (in [path], default
/// `~/.simutil/desktop-version`) and returns the previous one when [current]
/// is newer, i.e. the app was just updated. First runs return `null`.
Future<String?> versionBeforeUpdate({
  required String current,
  String? path,
}) async {
  try {
    final file = File(
      path ?? '${File(resolveStatePath()).parent.path}/desktop-version',
    );
    final previous = file.existsSync()
        ? (await file.readAsString()).trim()
        : null;
    if (previous != current) {
      await file.parent.create(recursive: true);
      await file.writeAsString(current);
    }
    return previous != null && isNewerVersion(current, previous)
        ? previous
        : null;
  } catch (_) {
    return null;
  }
}

/// Holds the available update, `null` while up to date or unchecked.
class AppUpdateCubit extends CubitSignal<AppUpdate?> {
  AppUpdateCubit({required this.currentVersion, HttpGet? httpGet})
    : _httpGet = httpGet ?? _get,
      super(initialState: null);

  /// From [getAppVersion].
  final String currentVersion;
  final HttpGet _httpGet;

  /// Checks GitHub once; offline or rate limited stays silent.
  Future<void> check() async {
    if (Platform.environment.containsKey('SIMUTIL_NO_UPDATE_CHECK')) return;
    try {
      final body = await _httpGet(Uri.parse(_releasesUrl));
      if (body != null) emit(newerAppRelease(body, currentVersion));
    } catch (_) {}
  }
}

Future<String?> _get(Uri uri) async {
  const timeout = Duration(seconds: 5);
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.getUrl(uri).timeout(timeout);
    // GitHub's API rejects requests without a User-Agent.
    request.headers.set(HttpHeaders.userAgentHeader, 'simutil-desktop');
    final response = await request.close().timeout(timeout);
    if (response.statusCode != HttpStatus.ok) return null;
    return await response.transform(utf8.decoder).join().timeout(timeout);
  } finally {
    client.close(force: true);
  }
}
