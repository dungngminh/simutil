import 'package:bloc_signals/bloc_signals.dart';
import 'package:equatable/equatable.dart';
import 'package:simutil_app/src/settings/desktop_settings_store.dart';
import 'package:simutil_core/simutil_core.dart';

/// Per-device options set from the device context menu.
final class DeviceSettings extends Equatable {
  const DeviceSettings({
    this.headless,
    this.maxSize = 1280,
    this.maxFps = 60,
    this.bitRateMbps = 8,
    this.showFrame = true,
    this.showTouches = false,
    this.stayAwake = true,
    this.turnScreenOff = false,
    this.powerOffOnClose = false,
    this.cameraBack,
    this.cameraFront,
  });

  /// Reads what [toJson] wrote; missing or invalid fields keep defaults.
  factory DeviceSettings.fromJson(Object? json) {
    const d = DeviceSettings();
    return DeviceSettings(
      headless: readField<bool>(json, 'headless'),
      maxSize: readField<int>(json, 'maxSize') ?? d.maxSize,
      maxFps: readField<int>(json, 'maxFps') ?? d.maxFps,
      bitRateMbps: readField<int>(json, 'bitRateMbps') ?? d.bitRateMbps,
      showFrame: readField<bool>(json, 'showFrame') ?? d.showFrame,
      showTouches: readField<bool>(json, 'showTouches') ?? d.showTouches,
      stayAwake: readField<bool>(json, 'stayAwake') ?? d.stayAwake,
      turnScreenOff: readField<bool>(json, 'turnScreenOff') ?? d.turnScreenOff,
      powerOffOnClose:
          readField<bool>(json, 'powerOffOnClose') ?? d.powerOffOnClose,
      cameraBack: readField<String>(json, 'cameraBack'),
      cameraFront: readField<String>(json, 'cameraFront'),
    );
  }

  /// Overrides the global headless toggle when set.
  final bool? headless;

  /// Android stream: longest side in pixels (0 = native).
  final int maxSize;

  /// Android stream frame-rate cap.
  final int maxFps;

  /// Android stream bit rate.
  final int bitRateMbps;

  /// Draw the device bezel around this device's stream.
  final bool showFrame;

  /// scrcpy: show taps on the device while streaming.
  final bool showTouches;

  /// scrcpy: keep the device awake while streaming.
  final bool stayAwake;

  /// scrcpy: turn the device's own screen off while streaming.
  final bool turnScreenOff;

  /// scrcpy: turn the screen off when the stream closes.
  final bool powerOffOnClose;

  /// Android emulator back / front camera source for the next boot (an
  /// `emulatorCameraArgs` source such as `webcam0` or `image:<path>`);
  /// null keeps the AVD's own setting.
  final String? cameraBack;
  final String? cameraFront;

  DeviceSettings copyWith({
    bool? Function()? headless,
    int? maxSize,
    int? maxFps,
    int? bitRateMbps,
    bool? showFrame,
    bool? showTouches,
    bool? stayAwake,
    bool? turnScreenOff,
    bool? powerOffOnClose,
    String? Function()? cameraBack,
    String? Function()? cameraFront,
  }) => DeviceSettings(
    headless: headless != null ? headless() : this.headless,
    maxSize: maxSize ?? this.maxSize,
    maxFps: maxFps ?? this.maxFps,
    bitRateMbps: bitRateMbps ?? this.bitRateMbps,
    showFrame: showFrame ?? this.showFrame,
    showTouches: showTouches ?? this.showTouches,
    stayAwake: stayAwake ?? this.stayAwake,
    turnScreenOff: turnScreenOff ?? this.turnScreenOff,
    powerOffOnClose: powerOffOnClose ?? this.powerOffOnClose,
    cameraBack: cameraBack != null ? cameraBack() : this.cameraBack,
    cameraFront: cameraFront != null ? cameraFront() : this.cameraFront,
  );

  Map<String, Object?> toJson() => {
    'headless': headless,
    'maxSize': maxSize,
    'maxFps': maxFps,
    'bitRateMbps': bitRateMbps,
    'showFrame': showFrame,
    'showTouches': showTouches,
    'stayAwake': stayAwake,
    'turnScreenOff': turnScreenOff,
    'powerOffOnClose': powerOffOnClose,
    'cameraBack': cameraBack,
    'cameraFront': cameraFront,
  };

  @override
  List<Object?> get props => [
    headless,
    maxSize,
    maxFps,
    bitRateMbps,
    showFrame,
    showTouches,
    stayAwake,
    turnScreenOff,
    powerOffOnClose,
    cameraBack,
    cameraFront,
  ];
}

/// Settings per device, keyed by name: an Android emulator's id changes
/// from AVD name to serial when it boots. Restored from and saved to
/// [store] when given.
class DeviceSettingsCubit extends CubitSignal<Map<String, DeviceSettings>> {
  DeviceSettingsCubit({DesktopSettingsStore? store})
    : _store = store,
      super(initialState: _read(store?.section(_key)));

  static const _key = 'devices';
  final DesktopSettingsStore? _store;

  static Map<String, DeviceSettings> _read(Object? json) => {
    if (json is Map)
      for (final MapEntry(:key, :value) in json.entries)
        if (key is String) key: DeviceSettings.fromJson(value),
  };

  @override
  void onChange(Change<Map<String, DeviceSettings>> change) {
    super.onChange(change);
    _store?.write(_key, {
      for (final MapEntry(:key, :value) in change.nextState.entries)
        key: value.toJson(),
    });
  }

  DeviceSettings of(Device device) =>
      stateValue[device.name] ?? const DeviceSettings();

  void update(Device device, DeviceSettings Function(DeviceSettings) change) =>
      emit({...stateValue, device.name: change(of(device))});
}
