import 'package:flutter/widgets.dart';
import 'package:simutil_app/src/settings/recordings_dir.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_app/src/ui/recording_toast.dart';

/// Starts or stops recording [deviceId]'s stream, and says why when that
/// fails (e.g. the simulator cannot write the file, or another recording
/// runs) instead of dropping the error.
Future<void> toggleDeviceRecording(
  BuildContext context,
  StreamsCubit streams,
  String deviceId,
) async {
  try {
    await streams.toggleRecording(deviceId, recordingsDirectory());
  } catch (e) {
    if (!context.mounted) return;
    showNotice(
      context,
      'Recording failed',
      subtitle: '$e',
      tone: NoticeTone.error,
    );
  }
}
