import 'dart:io';

import 'package:simutil_shared/simutil_shared.dart';
import 'package:test/test.dart';

void main() {
  group('detectInstallSource', () {
    InstallSource detect(String exe, [String? script]) =>
        detectInstallSource(executable: exe, script: script ?? exe);

    test('Homebrew Cellar binary', () {
      expect(
        detect('/opt/homebrew/Cellar/simutil/1.0.0/bin/simutil'),
        InstallSource.homebrew,
      );
      expect(
        detect('/home/linuxbrew/.linuxbrew/Cellar/simutil/1.0.0/bin/simutil'),
        InstallSource.homebrew,
      );
    });

    test('install.sh binary', () {
      expect(
        detect('/Users/me/.local/lib/simutil/simutil'),
        InstallSource.installScript,
      );
    });

    test('install.ps1 binary', () {
      expect(
        detect(r'C:\Users\me\AppData\Local\simutil\simutil.exe'),
        InstallSource.powershell,
      );
    });

    test('pub global snapshot run by Homebrew dart', () {
      expect(
        detect(
          '/opt/homebrew/Cellar/dart/3.11.0/libexec/bin/dart',
          '/Users/me/.pub-cache/global_packages/simutil/bin/simutil.dart-3.11.0.snapshot',
        ),
        InstallSource.pub,
      );
    });

    test('source checkout', () {
      expect(
        detect(
          '/usr/local/bin/dart',
          '/src/simutil/packages/simutil/bin/simutil.dart',
        ),
        InstallSource.source,
      );
    });

    test('unknown location', () {
      expect(detect('/usr/bin/simutil'), InstallSource.unknown);
    });
  });

  test('isNewerVersion', () {
    expect(isNewerVersion('1.0.1', '1.0.0'), isTrue);
    expect(isNewerVersion('1.10.0', '1.9.0'), isTrue);
    expect(isNewerVersion('2.0.0', '1.99.99'), isTrue);
    expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
    expect(isNewerVersion('0.9.0', '1.0.0'), isFalse);
    expect(isNewerVersion('1.1.0-dev.1', '1.0.0'), isFalse);
    expect(isNewerVersion('1.1.0', '1.0.0-dev'), isFalse);
  });

  group('UpdateChecker', () {
    late Directory dir;
    late AppStateService appState;
    final now = DateTime.utc(2026, 10, 4, 12);
    final requested = <Uri>[];

    setUp(() {
      dir = Directory.systemTemp.createTempSync('simutil_update_');
      appState = AppStateService(stateFilePath: '${dir.path}/state.json');
      requested.clear();
    });

    tearDown(() => dir.deleteSync(recursive: true));

    UpdateChecker checker(
      InstallSource source,
      String? body, {
      Map<String, String> env = const {},
    }) => UpdateChecker(
      appState: appState,
      source: source,
      environment: env,
      now: () => now,
      httpGet: (uri) async {
        requested.add(uri);
        return body;
      },
    );

    test('GitHub tag for Homebrew installs', () async {
      final info = await checker(
        InstallSource.homebrew,
        '{"tag_name":"v1.2.0"}',
      ).check('1.0.0');

      expect(requested.single.host, 'api.github.com');
      expect(info?.latestVersion, '1.2.0');
      expect(info?.instruction, 'simutil upgrade');
      expect(
        info?.source.upgradeCommand,
        'brew upgrade dungngminh/simutil/simutil',
      );
      expect((await appState.load()).latestKnownVersion, '1.2.0');
    });

    test('pub.dev for pub installs', () async {
      final info = await checker(
        InstallSource.pub,
        '{"latest":{"version":"1.1.0"}}',
      ).check('1.0.0');

      expect(requested.single.host, 'pub.dev');
      expect(info?.instruction, 'simutil upgrade');
    });

    test('unknown install points at releases page', () async {
      final info = await checker(
        InstallSource.unknown,
        '{"tag_name":"v1.1.0"}',
      ).check('1.0.0');

      expect(info?.instruction, simutilReleasesUrl);
    });

    test('fresh cache skips the network', () async {
      await appState.save(
        AppState(
          lastUpdateCheck: now.subtract(const Duration(hours: 1)),
          latestKnownVersion: '1.3.0',
        ),
      );

      final info = await checker(InstallSource.homebrew, null).check('1.0.0');

      expect(requested, isEmpty);
      expect(info?.latestVersion, '1.3.0');
    });

    test('up to date returns null', () async {
      final info = await checker(
        InstallSource.homebrew,
        '{"tag_name":"v1.0.0"}',
      ).check('1.0.0');

      expect(info, isNull);
    });

    test('offline stamps the check and returns null', () async {
      final info = await checker(InstallSource.homebrew, null).check('1.0.0');

      expect(info, isNull);
      expect((await appState.load()).lastUpdateCheck, now);
    });

    test('source checkouts follow GitHub releases', () async {
      final info = await checker(
        InstallSource.source,
        '{"tag_name":"v1.2.0"}',
      ).check('1.0.0');

      expect(requested.single.host, 'api.github.com');
      expect(info?.latestVersion, '1.2.0');
      expect(info?.instruction, simutilReleasesUrl);
    });

    test('force ignores opt-out env and the daily cache', () async {
      await appState.update(
        (s) => s.copyWith(lastUpdateCheck: now, latestKnownVersion: '1.0.0'),
      );
      final info = await checker(
        InstallSource.homebrew,
        '{"tag_name":"v1.2.0"}',
        env: {'SIMUTIL_NO_UPDATE_CHECK': '1'},
      ).check('1.0.0', force: true);

      expect(requested, hasLength(1));
      expect(info?.latestVersion, '1.2.0');
    });

    test('opt-out env skips everything', () async {
      expect(
        await checker(
          InstallSource.homebrew,
          '{"tag_name":"v9.0.0"}',
          env: {'SIMUTIL_NO_UPDATE_CHECK': '1'},
        ).check('1.0.0'),
        isNull,
      );
      expect(requested, isEmpty);
    });
  });
}
