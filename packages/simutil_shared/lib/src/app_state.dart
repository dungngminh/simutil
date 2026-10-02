import 'dart:convert';
import 'dart:io';

/// Returns the default path to `~/.simutil/state.json`.
String resolveStatePath() {
  final home = Platform.environment['HOME'] ?? '.';
  return '$home/.simutil/state.json';
}

/// Persisted app state such as the last seen release version.
class AppState {
  /// Creates app state with optional [lastSeenVersion].
  const AppState({this.lastSeenVersion});

  /// Last release version the user acknowledged in the changelog.
  final String? lastSeenVersion;

  /// Returns a copy with the given fields replaced.
  AppState copyWith({String? lastSeenVersion}) =>
      AppState(lastSeenVersion: lastSeenVersion ?? this.lastSeenVersion);
}

/// Loads and updates persisted [AppState] on disk.
abstract interface class AppStateService {
  /// File-backed service; [stateFilePath] defaults to [resolveStatePath].
  factory AppStateService({String? stateFilePath}) = _FileAppStateService;

  /// Reads state from disk, returning defaults when missing.
  Future<AppState> load();

  /// Writes [state] to the configured state file.
  Future<void> save(AppState state);

  /// Applies [updater] and persists the result.
  Future<AppState> update(AppState Function(AppState) updater);
}

final class _FileAppStateService implements AppStateService {
  _FileAppStateService({String? stateFilePath})
    : _stateFilePath = stateFilePath;

  final String? _stateFilePath;

  String get _statePath => _stateFilePath ?? resolveStatePath();

  @override
  Future<AppState> load() async {
    try {
      final decoded = jsonDecode(await File(_statePath).readAsString());
      if (decoded is! Map<String, dynamic>) return const AppState();
      return AppState(lastSeenVersion: decoded['lastSeenVersion'] as String?);
    } catch (_) {
      return const AppState();
    }
  }

  @override
  Future<void> save(AppState state) async {
    final file = File(_statePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({'lastSeenVersion': state.lastSeenVersion}),
    );
  }

  @override
  Future<AppState> update(AppState Function(AppState) updater) async {
    final current = await load();
    final updated = updater(current);
    await save(updated);
    return updated;
  }
}
