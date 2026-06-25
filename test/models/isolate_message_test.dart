import 'package:simutil/models/isolate_message.dart';
import 'package:test/test.dart';

void main() {
  group('IsolateRequest', () {
    test('applies defaults for optional fields', () {
      const request = IsolateRequest(
        id: 1,
        command: IsolateCommand.runCommand,
        executable: 'adb',
      );

      expect(request.arguments, isEmpty);
      expect(request.workingDirectory, isNull);
      expect(request.timeoutMs, isNull);
    });

    test('keeps provided values', () {
      const request = IsolateRequest(
        id: 2,
        command: IsolateCommand.shutdown,
        executable: 'emulator',
        arguments: ['-avd', 'Pixel'],
        workingDirectory: '/tmp',
        timeoutMs: 5000,
      );

      expect(request.arguments, ['-avd', 'Pixel']);
      expect(request.workingDirectory, '/tmp');
      expect(request.timeoutMs, 5000);
    });
  });

  group('IsolateResponse', () {
    test('applies defaults', () {
      const response = IsolateResponse(id: 1);

      expect(response.stdout, '');
      expect(response.stderr, '');
      expect(response.exitCode, -1);
      expect(response.error, isNull);
    });

    test('success requires exitCode 0 and no error', () {
      expect(const IsolateResponse(id: 1, exitCode: 0).success, isTrue);
      expect(const IsolateResponse(id: 1, exitCode: 1).success, isFalse);
      expect(
        const IsolateResponse(id: 1, exitCode: 0, error: 'boom').success,
        isFalse,
      );
    });
  });
}
