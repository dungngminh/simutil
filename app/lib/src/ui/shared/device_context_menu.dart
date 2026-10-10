import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_app/src/di.dart';
import 'package:simutil_app/src/devices/slim_mode_cubit.dart';
import 'package:simutil_app/src/recording/grid_recorder.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_app/src/settings/device_settings_cubit.dart';
import 'package:simutil_app/src/settings/recordings_dir.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_app/src/ui/shared/device_actions.dart';
import 'package:simutil_app/src/ui/shared/native_menu.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:tray_manager/tray_manager.dart' as native;

/// Opens a native context menu for [device] at the cursor: its actions plus
/// per-device settings.
void showDeviceContextMenu(BuildContext context, Device device) {
  final settingsCubit = context.read<DeviceSettingsCubit>();
  void set(DeviceSettings Function(DeviceSettings) change) =>
      settingsCubit.update(device, change);
  final busy = context.read<DevicesCubit>().stateValue.busy.contains(device.id);

  showNativeMenu(
    () => [
      _actionItems(context, device),
      if (!busy) _deviceItems(context, device),
      if (!device.type.isPhysical) _launchItems(context, device, set),
      _streamItems(context, device, set),
      if (!device.type.isPhysical && !busy) _deleteItems(context, device),
    ],
  );
}

/// Start / Stream / Stop, Restart, and controls for an open stream.
List<native.MenuItem> _actionItems(BuildContext context, Device device) {
  final devices = context.read<DevicesCubit>();
  final streams = context.read<StreamsCubit>();
  final commands = DeviceCommands(context, device);
  final session = streams.sessionFor(device.id);
  final idle = !devices.stateValue.busy.contains(device.id);
  return [
    for (final action in deviceActions(context, device, devices.stateValue))
      menuItem(action.label, action.onPressed),
    if (idle && !device.type.isPhysical && device.state == DeviceState.booted)
      menuItem('Restart', commands.restart),
    if (session != null) ...[
      // One recording at a time: no Record while the grid or another device
      // records.
      if (session.isRecording ||
          !(context.read<GridRecorderCubit>().isRecording ||
              streams.stateValue.entries.any(
                (e) => e.recording && e.device.id != device.id,
              )))
        menuItem(
          session.isRecording ? 'Stop recording' : 'Record',
          () => streams.toggleRecording(device.id, recordingsDirectory()),
        ),
      menuItem('Close stream', () => streams.closeStream(device.id)),
      if (session.status case SessionLive(inputBlocked: true))
        menuItem('Repair input (restarts apps)', session.repairInput),
    ],
  ];
}

/// Copy id, iOS slim mode.
List<native.MenuItem> _deviceItems(BuildContext context, Device device) {
  final devices = context.read<DevicesCubit>();
  final streams = context.read<StreamsCubit>();
  final slimMode = context.read<SlimModeCubit>();
  final slim = devices.stateValue.slimmed.contains(device.id);
  return [
    menuItem(
      device.os == DeviceOs.ios ? 'Copy UDID' : 'Copy serial',
      () => Clipboard.setData(ClipboardData(text: device.id)),
    ),
    if (device.os == DeviceOs.ios && !device.type.isPhysical)
      menuItem(
        slim
            ? 'Restore all services (reboots)'
            : 'Slim: disable background services (reboots)',
        () => slimMode.setSlim(device, on: !slim),
      ),
    if (device.os == DeviceOs.android &&
        device.type.isPhysical &&
        device.id.contains(':'))
      menuItem('Disconnect (Wi-Fi)', () async {
        await streams.closeStream(device.id);
        await getIt<AndroidDeviceService>().disconnectDevice(device.id);
        await devices.refresh(silent: true);
      }),
  ];
}

/// Boot options for the next start.
List<native.MenuItem> _launchItems(
  BuildContext context,
  Device device,
  void Function(DeviceSettings Function(DeviceSettings)) set,
) {
  final commands = DeviceCommands(context, device);
  final settings = commands.settings;
  return [
    menuCheck(
      'Start headless',
      commands.headless,
      () => set((s) => s.copyWith(headless: () => !commands.headless)),
    ),
    if (device.os == DeviceOs.android) ...[
      menuCheck(
        'Cold boot',
        settings.coldBoot,
        () => set((s) => s.copyWith(coldBoot: !s.coldBoot)),
      ),
      menuCheck(
        'No audio',
        settings.noAudio,
        () => set((s) => s.copyWith(noAudio: !s.noAudio)),
      ),
    ],
  ];
}

/// Device frame and Android stream quality.
List<native.MenuItem> _streamItems(
  BuildContext context,
  Device device,
  void Function(DeviceSettings Function(DeviceSettings)) set,
) {
  final streams = context.read<StreamsCubit>();
  final settings = context.read<DeviceSettingsCubit>().of(device);
  final android = device.os == DeviceOs.android;
  return [
    menuCheck(
      'Show device frame',
      settings.showFrame,
      () => set((s) => s.copyWith(showFrame: !s.showFrame)),
    ),
    if (android) ...[
      menuSubmenu('Stream resolution', [
        for (final size in const [720, 1080, 1280, 1920, 0])
          menuCheck(
            size == 0 ? 'Native' : '$size px',
            settings.maxSize == size,
            () => set((s) => s.copyWith(maxSize: size)),
          ),
      ]),
      menuSubmenu('Stream frame rate', [
        for (final fps in const [30, 60, 120])
          menuCheck(
            '$fps fps',
            settings.maxFps == fps,
            () => set((s) => s.copyWith(maxFps: fps)),
          ),
      ]),
      menuSubmenu('Stream bit rate', [
        for (final mbps in const [4, 8, 16, 24])
          menuCheck(
            '$mbps Mbps',
            settings.bitRateMbps == mbps,
            () => set((s) => s.copyWith(bitRateMbps: mbps)),
          ),
      ]),
      if (streams.sessionFor(device.id) != null)
        menuItem('Restart stream with new settings', () async {
          await streams.closeStream(device.id);
          await streams.open(device);
        }),
    ],
  ];
}

/// Delete behind a submenu, so one stray click cannot delete; only when
/// shut down.
List<native.MenuItem> _deleteItems(BuildContext context, Device device) {
  if (device.state != DeviceState.shutdown) {
    return [menuItem('Delete (shut down first)', null)];
  }
  final devices = context.read<DevicesCubit>();
  return [
    menuSubmenu('Delete…', [
      menuItem('Delete “${device.name}”', () => devices.delete(device)),
    ]),
  ];
}
