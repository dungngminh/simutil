import 'dart:io';

/// Where a running Android emulator serves its gRPC API, read from the
/// discovery file it writes (`<discovery dir>/pid_<pid>.ini`).
final class EmulatorEndpoint {
  /// Creates an endpoint on localhost [port].
  const EmulatorEndpoint({required this.port, this.token});

  /// gRPC port on localhost.
  final int port;

  /// Bearer token for the `authorization` header; null when the emulator
  /// accepts calls without one. Never log it.
  final String? token;

  /// The endpoint in a discovery file's [contents] when it belongs to the
  /// emulator with console port [serialPort] (`emulator-5554` → 5554).
  static EmulatorEndpoint? parse(String contents, {required int serialPort}) {
    final values = {
      for (final line in contents.split('\n'))
        if (line.indexOf('=') case final i when i > 0)
          line.substring(0, i).trim(): line.substring(i + 1).trim(),
    };
    if (int.tryParse(values['port.serial'] ?? '') != serialPort) return null;
    final port = int.tryParse(values['grpc.port'] ?? '');
    if (port == null) return null;
    final token = values['grpc.token'];
    return EmulatorEndpoint(
      port: port,
      token: token == null || token.isEmpty ? null : token,
    );
  }

  /// The gRPC endpoint of emulator [serial] (`emulator-<port>`), or null when
  /// it serves none (`-no-grpc`, emulators before 30) or is not running.
  static Future<EmulatorEndpoint?> find(
    String serial, {
    String? directory,
  }) async {
    final serialPort = int.tryParse(serial.replaceFirst('emulator-', ''));
    final dir = directory ?? discoveryDirectory(Platform.environment);
    if (serialPort == null || !serial.startsWith('emulator-') || dir == null) {
      return null;
    }
    final files = <File>[];
    try {
      await for (final entity in Directory(dir).list()) {
        final name = entity.uri.pathSegments.last;
        if (entity is File &&
            name.startsWith('pid_') &&
            name.endsWith('.ini')) {
          files.add(entity);
        }
      }
    } on FileSystemException {
      return null;
    }
    // A crashed emulator leaves its file behind: the newest one wins.
    // ponytail: a stale file with the same serial and a newer mtime than the
    // live one would win; check the pid is alive if that ever shows up.
    final candidates = <(DateTime, EmulatorEndpoint)>[];
    for (final file in files) {
      try {
        final endpoint = parse(
          await file.readAsString(),
          serialPort: serialPort,
        );
        if (endpoint != null) {
          candidates.add((await file.lastModified(), endpoint));
        }
      } on FileSystemException {
        continue;
      }
    }
    candidates.sort((a, b) => b.$1.compareTo(a.$1));
    return candidates.firstOrNull?.$2;
  }

  /// The emulator's discovery directory (`avd/running`) for the platform,
  /// from [environment] (Android Studio's `computeRegistrationDirectory`).
  static String? discoveryDirectory(
    Map<String, String> environment, {
    String? operatingSystem,
  }) {
    final base = switch (operatingSystem ?? Platform.operatingSystem) {
      'macos' => switch (environment['HOME']) {
        final home? => '$home/Library/Caches/TemporaryItems',
        null => null,
      },
      'windows' => switch (environment['LOCALAPPDATA']) {
        final local? => '$local\\Temp',
        null => null,
      },
      _ => switch (environment['XDG_RUNTIME_DIR']) {
        final runtime? when runtime.isNotEmpty => runtime,
        _ => '/tmp/android-${environment['USER'] ?? ''}',
      },
    };
    if (base == null) return null;
    final separator = base.contains('\\') ? '\\' : '/';
    return '$base${separator}avd${separator}running';
  }
}
