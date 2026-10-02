# simutil_core

Core models and process execution shared by the SimUtil packages: `Device`, `DeviceService`, `CommandExec`, and `IsolateRunner`. No user data or config files.

Part of [SimUtil](https://github.com/dungngminh/simutil).

## Usage

```dart
import 'package:simutil_core/simutil_core.dart';

Future<void> main() async {
  final result = await CommandExecImpl().run('adb', arguments: ['version']);
  print(result.stdout);
}
```

`package:simutil_core/testing.dart` provides test doubles (like `package:http/testing.dart`): `FakeCommandExec`, `FakeDeviceService`, and device fixtures (`testAndroidEmulator()`, `testIosSimulator()`, ...). Import it only from tests.
