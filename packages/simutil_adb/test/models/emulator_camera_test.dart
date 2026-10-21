import 'dart:io';

import 'package:simutil_adb/src/models/emulator_camera.dart';
import 'package:test/test.dart';

void main() {
  group('emulatorCameraArgs', () {
    test('is empty without sources', () {
      expect(emulatorCameraArgs(), isEmpty);
    });

    test('passes plain modes through', () {
      expect(emulatorCameraArgs(back: 'webcam1', front: 'none'), [
        '-camera-back',
        'webcam1',
        '-camera-front',
        'none',
      ]);
      expect(emulatorCameraArgs(back: 'virtualscene'), [
        '-camera-back',
        'virtualscene',
      ]);
    });

    test('maps image and video files to absolute paths', () {
      final dir = Directory.systemTemp.createTempSync('camera_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final image = File('${dir.path}/qr.png')..writeAsBytesSync([0]);
      final video = File('${dir.path}/clip.mp4')..writeAsBytesSync([0]);

      expect(
        emulatorCameraArgs(
          back: 'image:${image.path}',
          front: 'video:${video.path}',
        ),
        [
          '-camera-back',
          'imagefile:${image.absolute.path}',
          '-camera-front',
          'videofile:${video.absolute.path}',
        ],
      );
    });

    test('rejects unknown sources and missing files', () {
      expect(() => emulatorCameraArgs(back: 'phone'), throwsFormatException);
      expect(() => emulatorCameraArgs(back: 'webcam'), throwsFormatException);
      expect(() => emulatorCameraArgs(back: 'image:'), throwsFormatException);
      expect(
        () => emulatorCameraArgs(back: 'webcam0', front: 'webcam0'),
        throwsFormatException,
      );
      expect(
        () => emulatorCameraArgs(front: 'video:/no/such/file.mp4'),
        throwsFormatException,
      );
    });
  });
}
