import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:simutil/cli/commands/version_command.dart';

class SimutilCommandRunner extends CommandRunner<int> {
  SimutilCommandRunner({Logger? logger})
    : _logger = logger ?? Logger(),
      super(
        'simutil',
        'An utility TUI application for launching iOS simulators / Android emulators and more',
      ) {
    addCommand(VersionCommand(logger: _logger));
  }

  final Logger _logger;
}
