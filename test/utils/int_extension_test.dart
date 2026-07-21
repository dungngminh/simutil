import 'package:simutil/utils/int_extension.dart';
import 'package:test/test.dart';

void main() {
  group('IntExtension.formatBytes', () {
    test('formats zero and sub-kilobyte values as bytes', () {
      expect(0.formatBytes, '0B');
      expect(512.formatBytes, '512B');
    });

    test('formats KB / MB / GB scales', () {
      expect(1024.formatBytes, '1.0K');
      expect((10 * 1024).formatBytes, '10K');
      expect((1024 * 1024).formatBytes, '1.0M');
      // 3.9G ≈ 3.9 * 1024^3
      final almostFourG = (3.9 * 1024 * 1024 * 1024).round();
      expect(almostFourG.formatBytes, '3.9G');
    });

    test('clamps negative to zero', () {
      expect((-1).formatBytes, '0B');
    });
  });
}
