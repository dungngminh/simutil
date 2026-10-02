/// YAML plugin registry and command runner for SimUtil.
///
/// Parses the `plugins:` section of `~/.simutil/settings.yaml`, filters
/// commands by device, and launches external tools.
///
/// ```dart
/// import 'package:simutil_plugins/simutil_plugins.dart';
/// import 'package:simutil_core/simutil_core.dart';
///
/// final catalog = await loadPluginCatalog();
/// final runner = PluginRunner(CommandExecImpl());
/// final ref = catalog.command('scrcpy', 'mirror');
/// if (ref != null) await runner.run(ref.command, null);
/// ```
library;

export 'src/models/plugin_config.dart';
export 'src/plugin_catalog.dart';
export 'src/plugin_runner.dart';
export 'src/settings_file.dart';
