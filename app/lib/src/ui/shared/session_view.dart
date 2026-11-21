import 'package:flutter/widgets.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_app/src/stream/android/emulator_video_view.dart';
import 'package:simutil_app/src/stream/android/scrcpy_video_view.dart';
import 'package:simutil_app/src/stream/ios/ios_device_session.dart';
import 'package:simutil_app/src/stream/ios/ios_sim_session.dart';
import 'package:simutil_core/simutil_core.dart';

/// The video surface for a session's platform.
class SessionView extends StatelessWidget {
  const SessionView({super.key, required this.session});

  final DeviceSession session;

  @override
  Widget build(BuildContext context) => switch (session) {
    final ScrcpySession s => ScrcpyVideoView(session: s),
    final EmulatorGrpcSession s => EmulatorVideoView(session: s),
    IosSimSession(:final textureId?) || IosDeviceSession(:final textureId?) =>
      Texture(textureId: textureId, filterQuality: FilterQuality.low),
    _ => const SizedBox.shrink(),
  };
}
