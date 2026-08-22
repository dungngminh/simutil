import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

/// Base class for SimUtil CLI subcommands with shared [logger] access.
abstract class SimutilCommand extends Command<int> {
  /// Creates a subcommand, optionally with a custom [logger].
  SimutilCommand({Logger? logger}) : _logger = logger;

  /// Logger used for CLI output.
  Logger get logger => _logger ??= Logger();

  Logger? _logger;
  ArgParser? _configuredParser;

  /// Builds [super.argParser] once and applies [configure] on first access.
  ArgParser configuredArgParser(void Function(ArgParser parser) configure) {
    if (_configuredParser != null) return _configuredParser!;
    final parser = super.argParser;
    configure(parser);
    return _configuredParser = parser;
  }
}
