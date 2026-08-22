/// Headless CLI for SimUtil.
///
/// ```dart
/// import 'package:simutil_cli/simutil_cli.dart';
///
/// final runner = SimutilCommandRunner(version: '1.0.0');
/// await runner.run(['android', 'emulator', 'list']);
/// ```
library;

export 'src/cli_catalog.dart';
export 'src/cli_device_services.dart';
export 'src/cli_output.dart';
export 'src/simutil_command_runner.dart';
