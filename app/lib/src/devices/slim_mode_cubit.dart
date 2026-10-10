import 'package:bloc_signals/bloc_signals.dart';
import 'package:equatable/equatable.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_core/simutil_core.dart';

/// Slim mode: whether streamed and newly started simulators run slim, and
/// whether a switch is being applied.
final class SlimModeState extends Equatable {
  const SlimModeState({this.enabled = false, this.applying = false});

  /// Simulators run without background services (else: default).
  final bool enabled;

  /// Open simulators are rebooting into the new mode.
  final bool applying;

  @override
  List<Object?> get props => [enabled, applying];
}

/// The one path that changes a simulator's slim state: it closes the
/// stream, reboots the simulator through [DevicesCubit.setSlim] and reopens
/// the stream, so tiles never keep a session of the old boot.
class SlimModeCubit extends CubitSignal<SlimModeState> {
  SlimModeCubit({required DevicesCubit devices, required StreamsCubit streams})
    : _devices = devices,
      _streams = streams,
      super(initialState: const SlimModeState());

  final DevicesCubit _devices;
  final StreamsCubit _streams;

  /// Slims or restores one simulator, keeping its stream.
  Future<void> setSlim(Device device, {required bool on}) async {
    if (device.os != DeviceOs.ios || device.type.isPhysical) return;
    if (_devices.stateValue.slimmed.contains(device.id) == on) return;
    final reopen = _streams.stateValue.isOpen(device.id);
    if (reopen) await _streams.closeStream(device.id);
    await _devices.setSlim(device, on: on);
    if (!reopen) return;
    // After the reboot, so the old boot is not reopened.
    _streams
      ..openWhenBooted(device)
      ..onDevices(_devices.stateValue.all);
  }

  /// Switches the mode and moves every streamed simulator to it, one
  /// reboot at a time. Simulators started later follow the mode at launch.
  Future<void> setMode({required bool enabled}) async {
    if (stateValue.applying) return;
    emit(SlimModeState(enabled: enabled, applying: true));
    try {
      final simulators = [
        for (final entry in _streams.stateValue.entries)
          if (entry.device.os == DeviceOs.ios && !entry.device.type.isPhysical)
            entry.device,
      ];
      for (final device in simulators) {
        await setSlim(device, on: enabled);
      }
    } finally {
      if (!isClosed) emit(SlimModeState(enabled: enabled));
    }
  }
}
