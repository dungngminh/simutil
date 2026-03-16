import 'package:nocterm/nocterm.dart';
import 'package:simutil/cli/simutil_command_runner.dart';
import 'package:simutil/simutil_app.dart';

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    runApp(Navigator(home: SimutilApp()));
  } else {
    SimutilCommandRunner().run(arguments);
  }
}
