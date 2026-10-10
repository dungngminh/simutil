/// Android emulator and device APIs for SimUtil via adb.
///
/// Lists AVDs and hardware, launches the emulator, and handles wireless
/// `adb connect` / `adb pair`, and streams/controls devices through scrcpy
/// ([ScrcpySession]).
///
/// ```dart
/// import 'package:simutil_adb/simutil_adb.dart';
/// import 'package:simutil_core/simutil_core.dart';
///
/// final adb = AndroidDeviceService(CommandExec());
/// final avds = await adb.getSimulators();
/// ```
library;

export 'src/adb_wireless_pairing.dart';
export 'src/android_device_service.dart';
export 'src/logcat_helper.dart';
export 'src/scrcpy/scrcpy_install.dart';
export 'src/scrcpy/scrcpy_session.dart';
export 'src/models/adb_connect_result.dart';
export 'src/models/android_quick_launch_option.dart';
export 'src/models/wifi_pairing_device.dart';
export 'src/models/wireless_connect_request.dart';
export 'src/models/wireless_pairing_info.dart';
export 'src/wifi_discovery_service.dart';
