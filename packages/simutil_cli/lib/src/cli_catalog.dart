/// Full simutil CLI catalog for help and agent schema export.
List<CliCommandSpec> simutilCliCatalog({required String version}) => [
  _androidCommand(),
  _iosCommand(),
  CliCommandSpec(
    name: 'list',
    aliases: ['ls'],
    summary: 'List all devices (plain names; use -v for table)',
    usage: 'simutil list|ls [options]',
    flags: [
      ...cliPlatformFlags,
      CliFlagSpec(
        short: 'e',
        long: 'emulator',
        description: 'Include emulators and simulators',
        defaultValue: 'true',
      ),
      CliFlagSpec(
        short: 'p',
        long: 'physical',
        description: 'Include physical devices',
        defaultValue: 'true',
      ),
      CliFlagSpec(
        short: 'r',
        long: 'running',
        description: 'Show only running devices',
      ),
      CliFlagSpec(
        short: 'v',
        long: 'verbose',
        description: 'Show grouped tables with id, os, type, state',
      ),
      cliJsonFlag,
    ],
    examples: [
      'simutil list',
      'simutil ls -a -r',
      'simutil list -v',
      'simutil list --json',
    ],
  ),
  CliCommandSpec(
    name: 'launch',
    aliases: ['start'],
    summary: 'Boot an emulator or simulator by device id',
    usage: 'simutil launch|start <device-id> [options]',
    arguments: ['device-id — from list or android emulator list'],
    flags: [
      ...cliPlatformFlags,
      CliFlagSpec(
        short: 'c',
        long: 'cold',
        description: 'Cold boot (Android: -no-snapshot-load)',
      ),
      CliFlagSpec(
        long: 'no-audio',
        description: 'Disable emulator audio (Android)',
      ),
    ],
    examples: [
      'simutil launch Pixel_7_Pro_big_Android_15',
      'simutil start emulator-5554 -a',
      'simutil launch <avd> -c --no-audio',
    ],
  ),
  CliCommandSpec(
    name: 'shutdown',
    aliases: ['stop'],
    summary: 'Shut down a running emulator or simulator',
    usage: 'simutil shutdown|stop <device-id> [options]',
    arguments: ['device-id'],
    flags: cliPlatformFlags,
    examples: ['simutil shutdown emulator-5554', 'simutil stop <udid> -i'],
  ),
  _pluginCommand(),
  CliCommandSpec(
    name: 'schema',
    aliases: ['docs'],
    summary: 'CLI reference — JSON for agents (default), --human for text',
    usage: 'simutil schema [command-path] [options]',
    arguments: [
      'command-path — e.g. list, android emulator list',
    ],
    flags: [
      CliFlagSpec(
        short: 'H',
        long: 'human',
        description: 'Human-readable help instead of JSON',
      ),
    ],
    examples: [
      'simutil schema',
      'simutil schema android emulator list',
      'simutil schema list --human',
      'simutil list --help',
    ],
  ),
  CliCommandSpec(
    name: 'version',
    summary: 'Print the installed simutil version',
    usage: 'simutil version',
    examples: ['simutil version', 'simutil -V'],
  ),
];

CliCommandSpec _androidCommand() {
  const listFlags = [
    ...cliPlatformFlags,
    CliFlagSpec(
      short: 'r',
      long: 'running',
      description: 'Show only running devices',
    ),
    CliFlagSpec(
      short: 'v',
      long: 'verbose',
      description: 'Show full table instead of names only',
    ),
    cliJsonFlag,
  ];

  return CliCommandSpec(
    name: 'android',
    summary: 'Android emulators (AVD) and adb devices',
    usage: 'simutil android <emulator|device> list [options]',
    subcommands: [
      CliCommandSpec(
        name: 'emulator',
        summary: 'Android Virtual Devices',
        usage: 'simutil android emulator list [options]',
        subcommands: [
          CliCommandSpec(
            name: 'list',
            summary: 'List AVD names (one per line, like the screenshot)',
            usage: 'simutil android emulator list [options]',
            flags: listFlags,
            examples: [
              'simutil android emulator list',
              'simutil android emulator list -r',
              'simutil android emulator list --json',
              'simutil android emulator list -v',
            ],
          ),
        ],
      ),
      CliCommandSpec(
        name: 'device',
        summary: 'Physical devices visible to adb',
        usage: 'simutil android device list [options]',
        subcommands: [
          CliCommandSpec(
            name: 'list',
            summary: 'List connected Android hardware',
            usage: 'simutil android device list [options]',
            flags: listFlags,
            examples: [
              'simutil android device list',
              'simutil android device list -v --json',
            ],
          ),
        ],
      ),
    ],
    examples: [
      'simutil android emulator list',
      'simutil android device list -r',
    ],
  );
}

CliCommandSpec _iosCommand() {
  const listFlags = [
    ...cliPlatformFlags,
    CliFlagSpec(
      short: 'r',
      long: 'running',
      description: 'Show only running devices',
    ),
    CliFlagSpec(
      short: 'v',
      long: 'verbose',
      description: 'Show full table instead of names only',
    ),
    cliJsonFlag,
  ];

  return CliCommandSpec(
    name: 'ios',
    summary: 'Apple simulators and hardware (macOS only)',
    usage: 'simutil ios <simulator|device> list [options]',
    subcommands: [
      CliCommandSpec(
        name: 'simulator',
        summary: 'CoreSimulator devices',
        usage: 'simutil ios simulator list [options]',
        subcommands: [
          CliCommandSpec(
            name: 'list',
            summary: 'List simulator names',
            usage: 'simutil ios simulator list [options]',
            flags: listFlags,
            examples: ['simutil ios simulator list', 'simutil ios simulator list -v'],
          ),
        ],
      ),
      CliCommandSpec(
        name: 'device',
        summary: 'Physical Apple devices (devicectl)',
        usage: 'simutil ios device list [options]',
        subcommands: [
          CliCommandSpec(
            name: 'list',
            summary: 'List connected Apple hardware',
            usage: 'simutil ios device list [options]',
            flags: listFlags,
            examples: ['simutil ios device list'],
          ),
        ],
      ),
    ],
    examples: ['simutil ios simulator list', 'simutil ios device list -r'],
  );
}

CliCommandSpec _pluginCommand() => CliCommandSpec(
  name: 'plugin',
  summary: 'YAML plugins from ~/.simutil/settings.yaml',
  usage: 'simutil plugin <list|run> …',
  subcommands: [
    CliCommandSpec(
      name: 'list',
      summary: 'List plugins and commands',
      usage: 'simutil plugin list [options]',
      flags: [
        ...cliPlatformFlags,
        CliFlagSpec(
          short: 'd',
          long: 'device',
          kind: CliArgKind.option,
          valueName: 'id',
          description: 'Filter by device id',
        ),
        cliJsonFlag,
      ],
      examples: [
        'simutil plugin list',
        'simutil plugin list -d emulator-5554 --json',
      ],
    ),
    CliCommandSpec(
      name: 'run',
      summary: 'Run a plugin command',
      usage: 'simutil plugin run <plugin-id> <command-id> [options]',
      arguments: ['plugin-id', 'command-id'],
      flags: [
        ...cliPlatformFlags,
        CliFlagSpec(
          short: 'd',
          long: 'device',
          kind: CliArgKind.option,
          valueName: 'id',
          description: 'Target device for template args',
        ),
      ],
      examples: ['simutil plugin run scrcpy mirror -d emulator-5554'],
    ),
  ],
);

/// Kind of CLI argument in [CliFlagSpec].
enum CliArgKind {
  /// Boolean switch.
  flag,

  /// Option that takes a value.
  option,
}

/// Documents one flag or option for help text and agent schema export.
class CliFlagSpec {
  /// Creates flag documentation.
  const CliFlagSpec({
    this.short,
    required this.long,
    required this.description,
    this.kind = CliArgKind.flag,
    this.valueName,
    this.defaultValue,
  });

  /// Single-letter alias without the leading dash.
  final String? short;

  /// Long name without leading dashes.
  final String long;

  /// Human-readable description.
  final String description;

  /// Whether this is a flag or valued option.
  final CliArgKind kind;

  /// Placeholder for option values, e.g. `id`.
  final String? valueName;

  /// Documented default when relevant.
  final String? defaultValue;

  /// Renders `-a, --android` style names.
  String get names {
    if (short == null) return '--$long';
    return '-$short, --$long';
  }

  /// JSON map for agent consumption.
  Map<String, dynamic> toJson() => {
    if (short != null) 'short': short,
    'long': long,
    'description': description,
    'kind': kind.name,
    if (valueName != null) 'valueName': valueName,
    if (defaultValue != null) 'default': defaultValue,
  };
}

/// Metadata for a CLI command or command group.
class CliCommandSpec {
  /// Creates command documentation.
  const CliCommandSpec({
    required this.name,
    this.aliases = const [],
    required this.summary,
    required this.usage,
    this.flags = const [],
    this.arguments = const [],
    this.examples = const [],
    this.subcommands = const [],
  });

  /// Primary command name.
  final String name;

  /// Alternate names (`ls` for `list`).
  final List<String> aliases;

  /// One-line description.
  final String summary;

  /// Usage line shown in help.
  final String usage;

  /// Documented flags and options.
  final List<CliFlagSpec> flags;

  /// Positional argument descriptions.
  final List<String> arguments;

  /// Copy-paste examples including short flags.
  final List<String> examples;

  /// Nested subcommands when this entry is a group.
  final List<CliCommandSpec> subcommands;

  /// JSON map for agent consumption.
  Map<String, dynamic> toJson() => {
    'name': name,
    if (aliases.isNotEmpty) 'aliases': aliases,
    'summary': summary,
    'usage': usage,
    if (flags.isNotEmpty) 'flags': flags.map((f) => f.toJson()).toList(),
    if (arguments.isNotEmpty) 'arguments': arguments,
    if (examples.isNotEmpty) 'examples': examples,
    if (subcommands.isNotEmpty)
      'subcommands': subcommands.map((c) => c.toJson()).toList(),
  };
}

/// Shared platform filter flags used by several commands.
const cliPlatformFlags = <CliFlagSpec>[
  CliFlagSpec(
    short: 'a',
    long: 'android',
    description: 'Limit to Android devices',
  ),
  CliFlagSpec(
    short: 'i',
    long: 'ios',
    description: 'Limit to Apple (simulator + hardware) devices',
  ),
];

/// Shared machine-readable output flag.
const cliJsonFlag = CliFlagSpec(
  short: 'j',
  long: 'json',
  description: 'Emit JSON on stdout (for scripts and agents)',
);

/// Root schema document for agents (`simutil help --json`).
Map<String, dynamic> simutilCliSchema({required String version}) => {
  'tool': 'simutil',
  'version': version,
  'entry': 'simutil',
  'globalFlags': [
    const CliFlagSpec(
      short: 'V',
      long: 'version',
      description: 'Print version and exit',
    ).toJson(),
    const CliFlagSpec(
      short: 'h',
      long: 'help',
      description: 'Print usage for the nearest command',
    ).toJson(),
  ],
  'commands': simutilCliCatalog(version: version).map((c) => c.toJson()).toList(),
};

/// Finds a command spec by path (`plugin`, `android emulator list`, …).
CliCommandSpec? findCliCommandSpec(
  List<CliCommandSpec> catalog,
  List<String> path,
) {
  if (path.isEmpty) return null;
  CliCommandSpec? current;
  for (final catalogEntry in catalog) {
    if (catalogEntry.name == path.first ||
        catalogEntry.aliases.contains(path.first)) {
      current = catalogEntry;
      break;
    }
  }
  if (current == null) return null;
  var node = current;
  for (final segment in path.skip(1)) {
    CliCommandSpec? nested;
    for (final sub in node.subcommands) {
      if (sub.name == segment || sub.aliases.contains(segment)) {
        nested = sub;
        break;
      }
    }
    if (nested == null) return null;
    node = nested;
  }
  return node;
}

/// Formats a [CliCommandSpec] as human-readable help text.
String formatCliCommandHelp(CliCommandSpec spec) {
  final buffer = StringBuffer()
    ..writeln(spec.summary)
    ..writeln()
    ..writeln('Usage: ${spec.usage}');

  if (spec.arguments.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('Arguments:');
    for (final arg in spec.arguments) {
      buffer.writeln('  $arg');
    }
  }

  if (spec.flags.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('Options:');
    for (final flag in spec.flags) {
      final names = flag.names.padRight(22);
      final valueHint = flag.kind == CliArgKind.option
          ? ' <${flag.valueName ?? 'value'}>'
          : '';
      final defaultHint = flag.defaultValue != null
          ? ' (default: ${flag.defaultValue})'
          : '';
      buffer.writeln('  $names$valueHint  ${flag.description}$defaultHint');
    }
  }

  if (spec.subcommands.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('Subcommands:');
    for (final sub in spec.subcommands) {
      final aliases = sub.aliases.isEmpty ? '' : ' (${sub.aliases.join(', ')})';
      buffer.writeln('  ${sub.name}$aliases  ${sub.summary}');
    }
  }

  if (spec.examples.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('Examples:');
    for (final example in spec.examples) {
      buffer.writeln('  $example');
    }
  }

  return buffer.toString().trimRight();
}

/// Overview help listing top-level commands.
String formatCliOverviewHelp({
  required String version,
  required List<CliCommandSpec> catalog,
}) {
  final buffer = StringBuffer()
    ..writeln('Simutil v$version — device launcher CLI')
    ..writeln()
    ..writeln('Usage: simutil <command> [arguments] [options]')
    ..writeln()
    ..writeln('Global options:')
    ..writeln('  -h, --help     Show command help')
    ..writeln('  -V, --version  Print version')
    ..writeln('  -j, --json     With help: export schema for agents')
    ..writeln()
    ..writeln('Commands:');

  for (final command in catalog) {
    if (command.name == 'schema') continue;
    final aliases = command.aliases.isEmpty
        ? ''
        : ' (${command.aliases.join(', ')})';
    buffer.writeln(
      '  ${command.name.padRight(10)}$aliases  ${command.summary}',
    );
  }

  buffer
    ..writeln()
    ..writeln('Agent schema:  simutil schema')
    ..writeln('Human docs:    simutil schema --human [command-path]')
    ..writeln()
    ..writeln('Examples:')
    ..writeln('  simutil android emulator list')
    ..writeln('  simutil list -v')
    ..writeln('  simutil launch Pixel_7_Pro_big_Android_15')
    ..writeln('  simutil plugin run scrcpy mirror -d emulator-5554');

  return buffer.toString().trimRight();
}
