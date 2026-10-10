/// Only one recording runs at a time: the grid or a single device.
///
/// Shared by `GridRecorderCubit` and `StreamsCubit` so every entry point
/// (tiles, context menu, top bar, MCP) gets the same rule.
class RecordingLock {
  String? _holder;
  String? _label;

  /// Id of what is recording (`grid` or a device id), or null.
  String? get holder => _holder;

  /// Takes the lock for [holder]; [label] names it in errors. Throws
  /// [RecordingInProgress] while something else records.
  void acquire(String holder, {required String label}) {
    if (_holder case final current? when current != holder) {
      throw RecordingInProgress(_label ?? current);
    }
    _holder = holder;
    _label = label;
  }

  /// Frees the lock if [holder] has it.
  void release(String holder) {
    if (_holder != holder) return;
    _holder = null;
    _label = null;
  }
}

/// Thrown when a recording starts while another one runs.
class RecordingInProgress implements Exception {
  const RecordingInProgress(this.recording);

  /// What is already recording, e.g. `the grid` or a device name.
  final String recording;

  @override
  String toString() =>
      'Already recording $recording. Stop that recording first.';
}
