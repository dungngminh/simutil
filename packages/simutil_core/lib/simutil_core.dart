/// Core models and process execution for SimUtil.
///
/// Shared [Device] types, [DeviceService], [DeviceSession], and [CommandExec] used by
/// `simutil_adb`, `simutil_apple`, `simutil_plugins`, and the SimUtil app.
///
/// ```dart
/// import 'package:simutil_core/simutil_core.dart';
///
/// final exec = CommandExec();
/// final result = await exec.run('adb', arguments: ['devices']);
/// ```
library;

export 'src/command_exec.dart';
export 'src/command_queue.dart';
export 'src/device_service.dart';
export 'src/isolate_runner.dart';
export 'src/models/device.dart';
export 'src/models/device_os.dart';
export 'src/models/device_state.dart';
export 'src/models/device_type.dart';
export 'src/models/isolate_message.dart';
export 'src/session/device_session.dart';
export 'src/utils/streams.dart';
