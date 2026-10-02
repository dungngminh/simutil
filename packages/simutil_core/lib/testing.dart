/// Test doubles for `simutil_core`, in the style of `package:http/testing.dart`.
///
/// Import only from tests; production code uses `simutil_core.dart`.
///
/// ```dart
/// import 'package:simutil_core/testing.dart';
///
/// final exec = FakeCommandExec((cmd, args) => FakeCommandExec.ok('ok'));
/// final adb = FakeDeviceService(simulators: [testAndroidEmulator()]);
/// ```
library;

export 'src/testing/device_fixtures.dart';
export 'src/testing/fake_command_exec.dart';
export 'src/testing/fake_device_service.dart';
