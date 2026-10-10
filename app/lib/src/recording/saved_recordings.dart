import 'dart:async';
import 'dart:io';

import 'package:simutil_core/simutil_core.dart';

/// Files finished by any recorder (tile, grid, context menu, MCP), so the
/// UI can offer to open them.
class SavedRecordings {
  SavedRecordings(this._exec);

  final CommandExec _exec;
  final _saved = StreamController<String>.broadcast();

  Stream<String> get saved => _saved.stream;

  void add(String path) => _saved.add(path);

  /// Opens [path] in the default video player.
  Future<void> open(String path) => _exec.run(
    switch (Platform.operatingSystem) {
      'macos' => 'open',
      'windows' => 'explorer',
      _ => 'xdg-open',
    },
    arguments: [path],
  );

  /// Shows [path] in Finder / Explorer / the file manager.
  Future<void> reveal(String path) => switch (Platform.operatingSystem) {
    'macos' => _exec.run('open', arguments: ['-R', path]),
    'windows' => _exec.run('explorer', arguments: ['/select,$path']),
    _ => _exec.run('xdg-open', arguments: [File(path).parent.path]),
  };

  Future<void> dispose() => _saved.close();
}
