import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/recording/capture_file.dart';

void main() {
  final now = DateTime(2026, 11, 20, 10, 30, 5);

  test('a Wi-Fi adb serial becomes a valid file name', () {
    expect(
      captureFilePath(
        r'C:\Users\me\Videos\SimUtil',
        '192.168.1.5:5555',
        'mp4',
        now: now,
        separator: r'\',
      ),
      r'C:\Users\me\Videos\SimUtil\simutil-192.168.1.5_5555-'
      '2026-11-20T10-30-05.000.mp4',
    );
  });

  test('plain ids and the grid keep their name', () {
    expect(
      captureFilePath(
        '/movies',
        'emulator-5554',
        'png',
        now: now,
        separator: '/',
      ),
      '/movies/simutil-emulator-5554-2026-11-20T10-30-05.000.png',
    );
    expect(
      captureFilePath('/movies', 'grid', 'mp4', now: now, separator: '/'),
      '/movies/simutil-grid-2026-11-20T10-30-05.000.mp4',
    );
  });
}
