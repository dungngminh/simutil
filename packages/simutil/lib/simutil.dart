/// SimUtil app: terminal UI and headless CLI for Android emulators and iOS
/// simulators.
///
/// The `simutil` executable calls [runSimutilTui] without arguments and
/// [runSimutilCli] otherwise.
library;

export 'src/cli/cli_catalog.dart';
export 'src/cli/cli_device_services.dart';
export 'src/cli/cli_output.dart';
export 'src/cli/run_simutil_cli.dart';
export 'src/cli/simutil_command_runner.dart';
export 'src/tui/app/simutil_tui_app.dart' show SimutilTuiApp;
export 'src/tui/run_simutil_tui.dart';
export 'src/version.dart';
