import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/update/app_installer.dart';

UpdateChannel _detect(
  String os,
  String executable, {
  Map<String, String> environment = const {},
  Set<String> dirs = const {},
  bool releaseBuild = true,
}) => detectUpdateChannel(
  os: os,
  executable: executable,
  environment: environment,
  dirExists: dirs.contains,
  releaseBuild: releaseBuild,
);

void main() {
  const bundleExe = '/Applications/SimUtil.app/Contents/MacOS/SimUtil';

  test('macOS: Homebrew cask when its Caskroom exists, else DMG', () {
    expect(
      _detect(
        'macos',
        bundleExe,
        dirs: {'/opt/homebrew/Caskroom/simutil-desktop'},
      ),
      UpdateChannel.homebrew,
    );
    expect(_detect('macos', bundleExe), UpdateChannel.dmg);
    expect(appBundleOf(bundleExe), '/Applications/SimUtil.app');
  });

  test('Windows installer, Linux AppImage only under APPIMAGE', () {
    expect(
      _detect('windows', r'C:\Program Files\SimUtil\simutil_app.exe'),
      UpdateChannel.windowsInstaller,
    );
    expect(
      _detect(
        'linux',
        '/tmp/.mount_x/simutil_app',
        environment: {'APPIMAGE': '/home/u/.local/bin/simutil-desktop'},
      ),
      UpdateChannel.appImage,
    );
    expect(_detect('linux', '/opt/simutil/simutil_app'), UpdateChannel.manual);
  });

  test('debug builds never update in place', () {
    expect(
      _detect('macos', bundleExe, releaseBuild: false),
      UpdateChannel.manual,
    );
  });

  test('checksumFor reads sha256sum output', () {
    const body =
        'abc123  SimUtil-macos.dmg\n'
        'DEF456  SimUtil-windows-x64-setup.exe\n';
    expect(checksumFor(body, 'SimUtil-macos.dmg'), 'abc123');
    expect(checksumFor(body, 'SimUtil-windows-x64-setup.exe'), 'def456');
    expect(checksumFor(body, 'SimUtil-linux-x86_64.AppImage'), isNull);
  });
}
