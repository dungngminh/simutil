# simutil_adb

Android emulator and device APIs for SimUtil, built on `adb` and the Android `emulator` tool. Includes wireless ADB (IP / pair-code connect) and mDNS pairing discovery.

Part of [SimUtil](https://github.com/dungngminh/simutil).

## Usage

```dart
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_core/simutil_core.dart';

Future<void> main() async {
  final adb = AndroidDeviceService(CommandExec());
  for (final device in await adb.getSimulators()) {
    print('${device.id} ${device.name}');
  }
}
```

Android tooling resolves from `ANDROID_HOME` / `ANDROID_SDK_ROOT`, falling back to `~/Library/Android/sdk`.
