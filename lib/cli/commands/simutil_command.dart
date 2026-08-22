import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

/// Base class for SimUtil CLI subcommands with shared [logger] access.
abstract class SimutilCommand extends Command<int> {
  /// Creates a subcommand, optionally with a custom [logger].
  SimutilCommand({Logger? logger}) : _logger = logger;

  /// Logger used for CLI output.
  Logger get logger => _logger ??= Logger();

  Logger? _logger;
}
