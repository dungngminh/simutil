import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_app/src/devices/slim_mode_cubit.dart';
import 'package:simutil_app/src/recording/grid_record_quality.dart';
import 'package:simutil_app/src/settings/desktop_settings_store.dart';
import 'package:simutil_app/src/settings/device_settings_cubit.dart';
import 'package:simutil_app/src/settings/view_settings_cubit.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_core/testing.dart';

class _NoSlim implements SlimControl {
  @override
  Future<bool> isSlim(String udid) async => false;

  @override
  Future<void> setSlim(String udid, {required bool slim}) async {}
}

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('simutil_settings_');
    path = '${dir.path}/nested/desktop-settings.json';
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<DesktopSettingsStore> open() async {
    final store = DesktopSettingsStore(path: path);
    await store.load();
    return store;
  }

  test('missing file starts every cubit from its defaults', () async {
    final store = await open();
    expect(ViewSettingsCubit(store: store).stateValue, const ViewSettings());
    expect(DeviceSettingsCubit(store: store).stateValue, isEmpty);
  });

  test('corrupt or mistyped file falls back to defaults', () async {
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync('{not json');
    expect(
      ViewSettingsCubit(store: await open()).stateValue,
      const ViewSettings(),
    );

    File(path).writeAsStringSync(
      '{"view": {"headless": "yes", "layout": "nope", "gridQuality": 3},'
      ' "devices": {"Pixel": {"maxFps": "fast", "showFrame": false}}}',
    );
    final store = await open();
    expect(ViewSettingsCubit(store: store).stateValue, const ViewSettings());
    expect(DeviceSettingsCubit(store: store).stateValue, {
      'Pixel': const DeviceSettings(showFrame: false),
    });
  });

  test('view and device settings survive a restart', () async {
    final store = await open();
    final device = Device.android(
      id: 'emulator-5554',
      name: 'Pixel',
      state: DeviceState.booted,
      type: DeviceType.simulator,
    );
    // Every scrcpy option off its default.
    const scrcpy = DeviceSettings(
      headless: false,
      maxSize: 1920,
      maxFps: 120,
      bitRateMbps: 24,
      showFrame: false,
      showTouches: true,
      stayAwake: false,
      turnScreenOff: true,
      powerOffOnClose: true,
    );
    ViewSettingsCubit(store: store)
      ..toggleHeadless()
      ..setGridQuality(GridRecordQuality.high)
      ..spotlight('emulator-5554')
      ..setLayout(StreamLayout.spotlightHorizontal);
    DeviceSettingsCubit(store: store).update(device, (_) => scrcpy);
    await store.flush();

    final reopened = await open();
    expect(
      ViewSettingsCubit(store: reopened).stateValue,
      const ViewSettings(
        headless: false,
        layout: StreamLayout.spotlightHorizontal,
        spotlightId: 'emulator-5554',
        gridQuality: GridRecordQuality.high,
      ),
    );
    expect(DeviceSettingsCubit(store: reopened).of(device), scrcpy);
  });

  test('slim mode survives a restart', () async {
    final devices = DevicesCubit(
      android: FakeDeviceService(),
      ios: FakeDeviceService(),
      slim: _NoSlim(),
      slimOnLaunch: () => false,
    );
    final streams = StreamsCubit((_) => throw UnimplementedError());
    addTearDown(() async {
      await streams.close();
      await devices.close();
    });

    final store = await open();
    await SlimModeCubit(
      devices: devices,
      streams: streams,
      store: store,
    ).setMode(enabled: true);
    await store.flush();

    final reopened = SlimModeCubit(
      devices: devices,
      streams: streams,
      store: await open(),
    );
    expect(reopened.stateValue, const SlimModeState(enabled: true));
  });
}
