import 'package:simutil/models/adb_connect_result.dart';
import 'package:test/test.dart';

void main() {
  test('holds success flag and message', () {
    const result = AdbConnectResult(success: true, message: 'connected');

    expect(result.success, isTrue);
    expect(result.message, 'connected');
  });
}
