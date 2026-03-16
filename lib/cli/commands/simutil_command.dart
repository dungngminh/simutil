import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

abstract class SimutilCommand extends Command<int> {
  SimutilCommand({Logger? logger}) : _logger = logger;
  Logger get logger => _logger ??= Logger();

  Logger? _logger;
}
