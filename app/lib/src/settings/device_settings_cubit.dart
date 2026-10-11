import 'package:bloc_signals/bloc_signals.dart';
import 'package:equatable/equatable.dart';
import 'package:simutil_core/simutil_core.dart';

/// Per-device options set from the device context menu.
final class DeviceSettings extends Equatable {
  const DeviceSettings({
    this.headless,
    this.maxSize = 1280,
    this.maxFps = 60,
    this.bitRateMbps = 8,
    this.showFrame = true,
  });

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

  DeviceSettings copyWith({
    bool? Function()? headless,
    int? maxSize,
    int? maxFps,
    int? bitRateMbps,
    bool? showFrame,
  }) => DeviceSettings(
    headless: headless != null ? headless() : this.headless,
    maxSize: maxSize ?? this.maxSize,
    maxFps: maxFps ?? this.maxFps,
    bitRateMbps: bitRateMbps ?? this.bitRateMbps,
    showFrame: showFrame ?? this.showFrame,
  );

  @override
  List<Object?> get props => [
    headless,
    maxSize,
    maxFps,
    bitRateMbps,
    showFrame,
  ];
}

/// Settings per device, keyed by name: an Android emulator's id changes
/// from AVD name to serial when it boots.
class DeviceSettingsCubit extends CubitSignal<Map<String, DeviceSettings>> {
  DeviceSettingsCubit() : super(initialState: const {});

  DeviceSettings of(Device device) =>
      stateValue[device.name] ?? const DeviceSettings();

  void update(Device device, DeviceSettings Function(DeviceSettings) change) =>
      emit({...stateValue, device.name: change(of(device))});
}
