/// YAML plugin registry and command runner for SimUtil.
///
/// Parses the `plugins:` section of `~/.simutil/settings.yaml`, filters
/// commands by device, and launches external tools.
///
/// ```dart
/// import 'package:simutil_plugins/simutil_plugins.dart';
/// import 'package:simutil_core/simutil_core.dart';
///
/// final registry = PluginRegistryServiceImpl();
/// await registry.load();
/// final runner = PluginRunnerServiceImpl(CommandExecImpl());
/// ```
library;

export 'src/models/plugin_config.dart';
export 'src/services/plugin_registry_service.dart';
export 'src/services/plugin_runner_service.dart';
