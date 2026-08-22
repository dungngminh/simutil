import 'package:args/args.dart';
import 'package:simutil_cli/src/cli_catalog.dart';

/// Adds documented platform flags with short-flag hints in help text.
void addPlatformFlags(ArgParser parser) {
  if (parser.options.containsKey('android')) return;
  for (final flag in cliPlatformFlags) {
    parser.addFlag(
      flag.long,
      abbr: flag.short,
      help: '${flag.description} (${flag.names})',
      negatable: false,
    );
  }
}

/// Adds `-j, --json` when not already present.
void addJsonOutputFlag(ArgParser parser) {
  if (parser.options.containsKey('json')) return;
  parser.addFlag(
    cliJsonFlag.long,
    abbr: cliJsonFlag.short,
    help: '${cliJsonFlag.description} (${cliJsonFlag.names})',
    negatable: false,
  );
}

/// Adds `-v, --verbose` for detailed table output.
void addVerboseFlag(ArgParser parser) {
  if (parser.options.containsKey('verbose')) return;
  parser.addFlag(
    'verbose',
    abbr: 'v',
    help: 'Show full table with id, os, type, state (-v, --verbose)',
    negatable: false,
  );
}

/// Resolves a [CliCommandSpec] for this command name/path.
CliCommandSpec? specForCommand(String name, {List<String> path = const []}) {
  final catalog = simutilCliCatalog(version: '');
  final fullPath = [name, ...path];
  if (fullPath.length == 1) {
    for (final entry in catalog) {
      if (entry.name == name || entry.aliases.contains(name)) return entry;
    }
    return null;
  }
  return findCliCommandSpec(catalog, fullPath);
}

/// Builds usage text from the catalog when available.
String catalogUsage(String name, String fallback, {List<String> path = const []}) {
  return specForCommand(name, path: path)?.usage ?? fallback;
}
