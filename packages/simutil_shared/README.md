# simutil_shared

UI-agnostic app layer shared by the SimUtil TUI (`simutil_tui`) and the
desktop GUI: settings in `~/.simutil/settings.yaml`, app state in
`~/.simutil/state.json`, the bundled changelog, refresh intervals, and the
`ServiceLocator` that wires device and plugin services.

Part of [SimUtil](https://github.com/dungngminh/simutil).

## Usage

```dart
import 'package:simutil_shared/simutil_shared.dart';

Future<void> main() async {
  final services = ServiceLocator.instance;
  await services.init();
  final settings = await services.settingsService.load();
  print(settings.themeName);
  await services.dispose();
}
```

This package must not depend on `nocterm` or Flutter.
