# simutil_shared

UI-agnostic app layer shared by the SimUtil TUI (`simutil_tui`) and the
desktop GUI: settings in `~/.simutil/settings.yaml`, app state in
`~/.simutil/state.json`, the bundled changelog, and refresh intervals.

Part of [SimUtil](https://github.com/dungngminh/simutil).

## Usage

```dart
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_shared/simutil_shared.dart';

Future<void> main() async {
  final settings = await SettingsService(CommandExec()).load();
  print(settings.themeName);
}
```

This package must not depend on `nocterm` or Flutter.
