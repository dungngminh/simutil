import 'package:fake_async/fake_async.dart';
import 'package:simutil_core/testing.dart';
import 'package:simutil_shared/simutil_shared.dart';
import 'package:test/test.dart';

void main() {
  test('debounces bursts and keeps a fallback reload', () {
    fakeAsync((async) {
      final android = FakeDeviceService();
      final ios = FakeDeviceService();
      var reloads = 0;
      final watcher = DeviceChangeWatcher(
        [android, ios],
        () => reloads++,
        safetyInterval: const Duration(seconds: 60),
      )..start();
      async.flushMicrotasks();

      // One simulator boot: several file events in a burst.
      for (var i = 0; i < 5; i++) {
        ios.emitDeviceChange();
      }
      android.emitDeviceChange();
      async.elapse(const Duration(milliseconds: 299));
      expect(reloads, 0);
      async.elapse(const Duration(milliseconds: 1));
      expect(reloads, 1);

      async.elapse(const Duration(seconds: 60));
      expect(reloads, 2); // fallback

      watcher.stop();
      async.flushMicrotasks();
      ios.emitDeviceChange();
      async.elapse(const Duration(minutes: 5));
      expect(reloads, 2);
    });
  });
}
