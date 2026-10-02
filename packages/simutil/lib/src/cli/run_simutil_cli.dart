import 'dart:io';

import 'package:simutil/src/version.dart';
import 'package:args/command_runner.dart';
import 'package:simutil/src/cli/simutil_command_runner.dart';

/// Runs the SimUtil CLI with [arguments] and sets [exitCode].
///
/// Usage errors print the message and help to stderr and exit with `64`
/// (`EX_USAGE`) instead of throwing.
Future<void> runSimutilCli(List<String> arguments) async {
  try {
    exitCode =
        await SimutilCommandRunner(version: packageVersion).run(arguments) ?? 0;
  } on UsageException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln()
      ..writeln(e.usage);
    exitCode = 64;
  }
}
