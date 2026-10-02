# simutil_apple

Apple simulator and device APIs for SimUtil via `xcrun simctl` and `devicectl`, plus Xcode Derived Data size / clear helpers.

Part of [SimUtil](https://github.com/dungngminh/simutil).

## Usage

```dart
import 'dart:io';

import 'package:simutil_apple/simutil_apple.dart';
import 'package:simutil_core/simutil_core.dart';

Future<void> main() async {
  if (!Platform.isMacOS) return;
  final apple = IOSDeviceService(CommandExecImpl());
  for (final device in await apple.getSimulators()) {
    print('${device.id} ${device.name}');
  }
}
```

macOS only. Guard calls with `Platform.isMacOS`.
