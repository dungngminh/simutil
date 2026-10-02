import 'package:nocterm/nocterm.dart';
import 'package:simutil/src/tui/app/simutil_tui_app.dart';
import 'package:simutil/src/tui/terminal/tui_supervisor.dart';

/// Runs the SimUtil TUI until the user quits.
///
/// On Linux this supervises a re-executed child process so the terminal is
/// restored after exit; elsewhere it runs in-process.
Future<void> runSimutilTui() async {
  if (shouldSuperviseTui) {
    await runTuiSupervisor();
    return;
  }
  await runApp(Navigator(home: const SimutilTuiApp()));
}
