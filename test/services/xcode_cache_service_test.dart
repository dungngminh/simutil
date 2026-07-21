import 'dart:io';

import 'package:simutil/services/xcode_cache_service.dart';
import 'package:simutil/utils/int_extension.dart';
import 'package:test/test.dart';

import 'fake_command_exec.dart';

void main() {
  group('XcodeCacheService.derivedDataPathFor', () {
    test('builds path under home', () {
      expect(
        XcodeCacheService.derivedDataPathFor('/Users/dev'),
        '/Users/dev/Library/Developer/Xcode/DerivedData',
      );
    });
  });

  group('XcodeCacheService.getDerivedDataSizeBytes', () {
    test('parses du -sk output to bytes', () async {
      final exec = FakeCommandExec((command, args) {
        if (command == 'du' && args.contains('-sk')) {
          return FakeCommandExec.ok('3987456\t/Users/dev/Library/Developer/Xcode/DerivedData\n');
        }
        return null;
      });
      final service = XcodeCacheService(exec, homeDirectory: '/Users/dev');

      if (!Platform.isMacOS) {
        expect(await service.getDerivedDataSizeBytes(), isNull);
        return;
      }

      final size = await service.getDerivedDataSizeBytes();
      expect(size, 3987456 * 1024);
      expect(exec.calls, hasLength(1));
      expect(exec.calls.single.command, 'du');
      expect(exec.calls.single.arguments, [
        '-sk',
        '/Users/dev/Library/Developer/Xcode/DerivedData',
      ]);
    });

    test('returns null when du fails', () async {
      final exec = FakeCommandExec((command, args) {
        if (command == 'du') return FakeCommandExec.fail('No such file');
        return null;
      });
      final service = XcodeCacheService(exec, homeDirectory: '/Users/dev');

      if (!Platform.isMacOS) {
        expect(await service.getDerivedDataSizeBytes(), isNull);
        return;
      }

      expect(await service.getDerivedDataSizeBytes(), isNull);
    });

    test('returns null when du output is unparseable', () async {
      final exec = FakeCommandExec(
        (command, args) => FakeCommandExec.ok('not-a-number\tpath\n'),
      );
      final service = XcodeCacheService(exec, homeDirectory: '/Users/dev');

      if (!Platform.isMacOS) {
        expect(await service.getDerivedDataSizeBytes(), isNull);
        return;
      }

      expect(await service.getDerivedDataSizeBytes(), isNull);
    });
  });

  group('XcodeCacheService.clearDerivedData', () {
    test('runs rm then mkdir and reports freed size', () async {
      final exec = FakeCommandExec((command, args) {
        if (command == 'du') {
          return FakeCommandExec.ok('2048\t/Users/dev/Library/Developer/Xcode/DerivedData\n');
        }
        if (command == 'rm') return FakeCommandExec.ok();
        if (command == 'mkdir') return FakeCommandExec.ok();
        return null;
      });
      final service = XcodeCacheService(exec, homeDirectory: '/Users/dev');

      if (!Platform.isMacOS) {
        final result = await service.clearDerivedData();
        expect(result.success, isFalse);
        expect(result.message, contains('macOS'));
        return;
      }

      final result = await service.clearDerivedData();
      expect(result.success, isTrue);
      expect(result.freedBytes, 2048 * 1024);
      expect(result.message, contains((2048 * 1024).formatBytes));

      final commands = exec.calls.map((c) => c.command).toList();
      expect(commands, containsAllInOrder(['du', 'rm', 'mkdir']));
      final rmCall = exec.calls.firstWhere((c) => c.command == 'rm');
      expect(rmCall.arguments, [
        '-rf',
        '/Users/dev/Library/Developer/Xcode/DerivedData',
      ]);
      final mkdirCall = exec.calls.firstWhere((c) => c.command == 'mkdir');
      expect(mkdirCall.arguments, [
        '-p',
        '/Users/dev/Library/Developer/Xcode/DerivedData',
      ]);
    });

    test('reports already empty when size is zero', () async {
      final exec = FakeCommandExec((command, args) {
        if (command == 'du') {
          return FakeCommandExec.ok('0\t/Users/dev/Library/Developer/Xcode/DerivedData\n');
        }
        if (command == 'rm' || command == 'mkdir') return FakeCommandExec.ok();
        return null;
      });
      final service = XcodeCacheService(exec, homeDirectory: '/Users/dev');

      if (!Platform.isMacOS) return;

      final result = await service.clearDerivedData();
      expect(result.success, isTrue);
      expect(result.message, contains('already empty'));
      expect(result.freedBytes, 0);
    });

    test('fails when rm fails', () async {
      final exec = FakeCommandExec((command, args) {
        if (command == 'du') {
          return FakeCommandExec.ok('100\tpath\n');
        }
        if (command == 'rm') {
          return FakeCommandExec.fail('Permission denied');
        }
        return null;
      });
      final service = XcodeCacheService(exec, homeDirectory: '/Users/dev');

      if (!Platform.isMacOS) return;

      final result = await service.clearDerivedData();
      expect(result.success, isFalse);
      expect(result.message, contains('Permission denied'));
      expect(exec.calls.any((c) => c.command == 'mkdir'), isFalse);
    });

    test('fails when mkdir fails after rm', () async {
      final exec = FakeCommandExec((command, args) {
        if (command == 'du') return FakeCommandExec.ok('50\tpath\n');
        if (command == 'rm') return FakeCommandExec.ok();
        if (command == 'mkdir') return FakeCommandExec.fail('disk full');
        return null;
      });
      final service = XcodeCacheService(exec, homeDirectory: '/Users/dev');

      if (!Platform.isMacOS) return;

      final result = await service.clearDerivedData();
      expect(result.success, isFalse);
      expect(result.message, contains('could not be recreated'));
      expect(result.message, contains('disk full'));
    });
  });
}
