/// Parsing, filtering, and path detection for Android logcat lines.
///
/// Expects threadtime-style lines:
/// `MM-DD HH:MM:SS.mmm  PID  TID  L tag  : message`
class LogcatHelper {
  LogcatHelper._();

  static final RegExp _logLevelRe = RegExp(
    r'^\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+\s+\d+\s+\d+\s+([VDIWEF])\s',
  );

  static final RegExp pathRe = RegExp(r'(/[^\s\x00-\x1f\)\]\x22\x27,:;]+)');

  static LogcatLevel parseLevel(String line) {
    final m = _logLevelRe.firstMatch(line);
    if (m == null) return LogcatLevel.unknown;
    return switch (m.group(1)) {
      'V' => LogcatLevel.verbose,
      'D' => LogcatLevel.debug,
      'I' => LogcatLevel.info,
      'W' => LogcatLevel.warning,
      'E' => LogcatLevel.error,
      'F' => LogcatLevel.fatal,
      _ => LogcatLevel.unknown,
    };
  }

  /// Java [FATAL EXCEPTION], native [Fatal signal], tombstone header, or `F` level.
  static bool looksLikeCrash(String line) {
    final level = parseLevel(line);
    if (level == LogcatLevel.fatal) return true;
    final lower = line.toLowerCase();
    if (lower.contains('fatal exception')) return true;
    if (lower.contains('fatal signal')) return true;
    if (lower.contains('beginning of crash')) return true;
    return false;
  }

  static bool lineMatchesFilter(String line, String filter) {
    if (filter.isEmpty) return true;
    final f = filter.trim().toLowerCase();
    final level = parseLevel(line);
    return switch (f) {
      'is:error' => level == LogcatLevel.error || level == LogcatLevel.fatal,
      'is:crash' => looksLikeCrash(line),
      'is:warn' => level == LogcatLevel.warning,
      'is:info' => level == LogcatLevel.info,
      'is:debug' => level == LogcatLevel.debug,
      'is:verbose' => level == LogcatLevel.verbose,
      _ => line.toLowerCase().contains(f),
    };
  }

  static String? firstPath(String line) => pathRe.firstMatch(line)?.group(1);
}

enum LogcatLevel { verbose, debug, info, warning, error, fatal, unknown }
