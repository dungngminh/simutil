import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:simutil/src/cli/cli_catalog.dart';
import 'package:simutil/src/cli/cli_output.dart';
import 'package:simutil/src/cli/commands/simutil_command.dart';

/// Exports CLI schema for agents (default) or human-readable command docs.
class SchemaCommand extends SimutilCommand {
  /// Creates the `schema` subcommand.
  SchemaCommand({super.logger, required this.version});

  /// App version embedded in schema export.
  final String version;

  @override
  String get name => 'schema';

  @override
  List<String> get aliases => const ['docs'];

  @override
  String get description =>
      'CLI reference (JSON by default; use --human for readable help)';

  @override
  ArgParser get argParser => configuredArgParser((parser) {
    parser.addFlag(
      'human',
      abbr: 'H',
      help: 'Human-readable text instead of JSON (-H, --human)',
      negatable: false,
    );
  });

  List<CliCommandSpec> get _catalog => simutilCliCatalog(version: version);

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    final human = argResults!['human'] == true;

    if (rest.isEmpty) {
      if (human) {
        logger.info(formatCliOverviewHelp(version: version, catalog: _catalog));
        return 0;
      }
      writeJsonStdout(simutilCliSchema(version: version));
      return 0;
    }

    final path = rest.join(' ').split(' ');
    final spec = findCliCommandSpec(_catalog, path);
    if (spec == null) {
      throw UsageException('Unknown command path: ${rest.join(' ')}', usage);
    }

    if (human) {
      logger.info(formatCliCommandHelp(spec));
      return 0;
    }

    writeJsonStdout(spec.toJson());
    return 0;
  }
}
