# simutil_plugins

YAML plugin registry and command runner for SimUtil. Reads the `plugins:` section of `~/.simutil/settings.yaml`, expands `{device.*}` templates, and launches the configured commands.

Part of [SimUtil](https://github.com/dungngminh/simutil).

## Usage

```dart
import 'package:simutil_plugins/simutil_plugins.dart';

Future<void> main() async {
  final catalog = await loadPluginCatalog();
  catalog.warnings.forEach(print);
  for (final plugin in catalog.plugins) {
    print(plugin.label);
  }
}
```

See the [plugin docs](https://github.com/dungngminh/simutil/blob/main/docs/plugins.md) for the YAML format.

`package:simutil_plugins/testing.dart` provides `FakePluginRunner` for tests.
