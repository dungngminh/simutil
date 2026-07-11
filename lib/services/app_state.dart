import 'dart:convert';
import 'dart:io';

String resolveStatePath() {
  final home = Platform.environment['HOME'] ?? '.';
  return '$home/.simutil/state.json';
}

class AppState {
  const AppState({this.lastSeenVersion});

  final String? lastSeenVersion;

  AppState copyWith({String? lastSeenVersion}) =>
      AppState(lastSeenVersion: lastSeenVersion ?? this.lastSeenVersion);
}

abstract class AppStateService {
  Future<AppState> load();
  Future<AppState> update(AppState Function(AppState) updater);
}

class AppStateServiceImpl implements AppStateService {
  AppStateServiceImpl({String? stateFilePath}) : _stateFilePath = stateFilePath;

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
