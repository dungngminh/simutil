import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/stream/ios/sim_camera.dart';
import 'package:simutil_core/simutil_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parse reads webcam, image and video values', () {
    expect(SimCamera.parse('webcam'), (source: 'webcam', arg: null));
    expect(SimCamera.parse('webcam:FaceTime'), (
      source: 'webcam',
      arg: 'FaceTime',
    ));
    expect(SimCamera.parse('image:/a/b:c.png'), (
      source: 'image',
      arg: '/a/b:c.png',
    ));
    expect(() => SimCamera.parse('video:'), throwsFormatException);
    expect(() => SimCamera.parse('virtualscene'), throwsFormatException);
  });

  test('onDevices stops the feed of a simulator that shut down', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('simutil/sim_camera'), (
          call,
        ) async {
          calls.add(call);
          return call.method == 'start' ? {'shm': '/s', 'dylib': '/d'} : null;
        });
    Device sim(DeviceState state) => Device.ios(
      id: 'UDID',
      name: 'iPhone',
      state: state,
      type: DeviceType.simulator,
    );
    await SimCamera.setSource('UDID', 'webcam');

    SimCamera.onDevices([sim(DeviceState.booted)]);
    expect(calls.map((c) => c.method), ['start']);

    SimCamera.onDevices([sim(DeviceState.shutdown)]);
    SimCamera.onDevices([sim(DeviceState.shutdown)]);
    expect(calls.map((c) => c.method), ['start', 'stop']);
    expect(calls.last.arguments, {'udid': 'UDID'});
  });
}
