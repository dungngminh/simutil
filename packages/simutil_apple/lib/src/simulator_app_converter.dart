import 'dart:io';

import 'package:simutil_core/simutil_core.dart';

/// Makes the device-built (iphoneos, arm64) app bundle at [app] run on an
/// Apple Silicon iOS simulator, in place, so pass a copy.
///
/// Simulators on Apple Silicon run arm64 code natively; only the platform
/// recorded in each Mach-O's `LC_BUILD_VERSION` stops installd and dyld from
/// loading it. Every Mach-O in the bundle is thinned to arm64 (`lipo`),
/// re-tagged as iOS Simulator (`vtool`) and the bundle is ad hoc re-signed
/// inside out (`codesign -s -`), since the edit breaks the signature.
/// Entitlements (keychain groups, app groups, push) are lost.
///
/// Throws a [StateError] when the app is FairPlay-encrypted (an App Store
/// download) or a tool fails.
Future<void> convertForSimulator(CommandExec exec, String app) async {
  Future<CommandResult> run(String tool, List<String> args) async {
    final result = await exec.run(
      tool,
      arguments: args,
      timeout: const Duration(minutes: 1),
    );
    if (!result.success) {
      throw StateError('$tool failed: ${result.stderr}'.trim());
    }
    return result;
  }

  final binaries = _machOFiles(app);
  for (final binary in binaries) {
    final load = await run('otool', ['-l', binary.path]);
    if (load.stdout.contains(RegExp(r'cryptid\s+1'))) {
      throw StateError(
        '${app.split('/').last} is encrypted (an App Store download), so it '
        'cannot run on a simulator.',
      );
    }
  }
  for (final binary in binaries) {
    final path = binary.path;
    if (binary.fat) {
      await run('lipo', [path, '-thin', 'arm64', '-output', '$path.thin']);
      File('$path.thin').renameSync(path);
    }
    final build = await exec.run('vtool', arguments: ['-show-build', path]);
    String version(String key, String fallback) =>
        RegExp('$key ([0-9.]+)').firstMatch(build.stdout)?[1] ?? fallback;
    await run('vtool', [
      '-set-build-version',
      'iossim',
      version('minos', '14.0'),
      version('sdk', '17.0'),
      '-replace',
      '-output',
      '$path.sim',
      path,
    ]);
    File('$path.sim').renameSync(path);
  }
  // Nested code first: a bundle's signature seals what it contains.
  final nested =
      Directory(app)
          .listSync(recursive: true, followLinks: false)
          .map((e) => e.path)
          .where(
            (p) =>
                p.endsWith('.framework') ||
                p.endsWith('.appex') ||
                p.endsWith('.dylib'),
          )
          .toList()
        ..sort((a, b) => b.split('/').length.compareTo(a.split('/').length));
  for (final path in [...nested, app]) {
    await run('codesign', ['-f', '-s', '-', path]);
  }
}

/// Mach-O files under [app], by magic number; `fat` for universal binaries
/// (e.g. armv7 + arm64).
List<({String path, bool fat})> _machOFiles(String app) {
  final found = <({String path, bool fat})>[];
  for (final entry in Directory(
    app,
  ).listSync(recursive: true, followLinks: false)) {
    if (entry is! File) continue;
    final RandomAccessFile file;
    try {
      file = entry.openSync();
    } on FileSystemException {
      continue;
    }
    final magic = file.readSync(4);
    file.closeSync();
    if (magic.length < 4) continue;
    final word = magic[0] << 24 | magic[1] << 16 | magic[2] << 8 | magic[3];
    // MH_MAGIC_64 is stored little-endian; FAT_MAGIC big-endian.
    if (word == 0xcffaedfe) found.add((path: entry.path, fat: false));
    if (word == 0xcafebabe) found.add((path: entry.path, fat: true));
  }
  return found;
}
