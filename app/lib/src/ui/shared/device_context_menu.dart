import 'dart:io';

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_apple/simutil_apple.dart';
import 'package:simutil_app/src/di.dart';
import 'package:simutil_app/src/devices/slim_mode_cubit.dart';
import 'package:simutil_app/src/recording/grid_recorder.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_app/src/settings/device_settings_cubit.dart';
import 'package:simutil_app/src/settings/recordings_dir.dart';
import 'package:simutil_app/src/stream/ios/sim_camera.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_app/src/ui/shared/device_actions.dart';
import 'package:simutil_app/src/ui/shared/native_menu.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:tray_manager/tray_manager.dart' as native;

// ponytail: listed once per run, so a camera plugged in later needs an app
// restart; re-list on every menu open if that matters.
Future<List<({String id, String name})>>? _webcams;
Future<List<({String id, String name})>>? _hostWebcams;

/// What an iOS simulator's Camera submenu shows: the host webcams, the
/// running feed and the apps that can be launched with it.
typedef _SimCameraState = ({
  List<({String id, String name})> webcams,
  ({String source, String? arg})? current,
  List<({String id, String name})> apps,
});

Future<_SimCameraState> _simCameraState(Device device) async {
  final apps = getIt<IosAutomation>()
      .installedApps(device)
      .catchError((Object _) => <({String id, String name})>[]);
  return (
    webcams: await (_hostWebcams ??= SimCamera.webcams()),
    current: await SimCamera.status(device.id),
    apps: await apps,
  );
}

Future<List<({String id, String name})>> _listWebcams() =>
    _webcams ??= getIt<AndroidDeviceService>().listWebcams();

/// The camera sources of a running device as their own menu (from its
/// stream header). An Android emulator restarts so the camera changes right
/// away; an iOS simulator's feed switches live.
Future<void> showCameraMenu(BuildContext context, Device device) async {
  if (device.os == DeviceOs.ios) {
    final state = await _simCameraState(device);
    if (!context.mounted) return;
    showNativeMenu(() => [_simCameraItems(context, device, state)]);
    return;
  }
  final webcams = await _listWebcams();
  if (!context.mounted) return;
  final settingsCubit = context.read<DeviceSettingsCubit>();
  showNativeMenu(
    () => [
      _cameraSides(settingsCubit.of(device), webcams, (change) {
        settingsCubit.update(device, change);
        if (context.mounted) DeviceCommands(context, device).restart();
      }),
    ],
  );
}

/// Opens a native context menu for [device] at the cursor: its actions plus
/// per-device settings.
Future<void> showDeviceContextMenu(BuildContext context, Device device) async {
  final emulator = device.os == DeviceOs.android && !device.type.isPhysical;
  final webcams = emulator
      ? await _listWebcams()
      : const <({String id, String name})>[];
  final simCamera =
      Platform.isMacOS &&
          device.os == DeviceOs.ios &&
          !device.type.isPhysical &&
          device.state == DeviceState.booted
      ? await _simCameraState(device)
      : null;
  if (!context.mounted) return;
  final settingsCubit = context.read<DeviceSettingsCubit>();
  void set(DeviceSettings Function(DeviceSettings) change) =>
      settingsCubit.update(device, change);
  final busy = context.read<DevicesCubit>().stateValue.busy.contains(device.id);

  showNativeMenu(
    () => [
      _actionItems(context, device),
      if (!busy) _deviceItems(context, device),
      if (!device.type.isPhysical) _launchItems(context, device, set),
      if (emulator)
        [
          menuSubmenu(
            'Camera (next boot)',
            _cameraSides(settingsCubit.of(device), webcams, set),
          ),
        ],
      if (simCamera != null)
        [menuSubmenu('Camera', _simCameraItems(context, device, simCamera))],
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
        slim ? 'Restore services (reboots)' : 'Slim (reboots)',
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

/// Headless for every start, and one-off launch modes for a shut-down
/// Android emulator.
List<native.MenuItem> _launchItems(
  BuildContext context,
  Device device,
  void Function(DeviceSettings Function(DeviceSettings)) set,
) {
  final commands = DeviceCommands(context, device);
  return [
    menuCheck(
      'Start headless',
      commands.headless,
      () => set((s) => s.copyWith(headless: () => !commands.headless)),
    ),
    if (device.os == DeviceOs.android &&
        device.state == DeviceState.shutdown &&
        !context.read<DevicesCubit>().stateValue.busy.contains(device.id)) ...[
      menuItem('Launch with Cold Boot', () => commands.start(coldBoot: true)),
      menuItem('Launch with No Audio', () => commands.start(noAudio: true)),
      menuItem(
        'Launch with Cold Boot and No Audio',
        () => commands.start(coldBoot: true, noAudio: true),
      ),
    ],
  ];
}

/// Back / front camera source of an Android emulator, used from its next
/// boot: the AVD default, the emulator's fake camera, a host webcam, an
/// image or a video file.
List<native.MenuItem> _cameraSides(
  DeviceSettings settings,
  List<({String id, String name})> webcams,
  void Function(DeviceSettings Function(DeviceSettings)) set,
) {
  native.MenuItem side(
    String label,
    String? current, {
    required bool back,
    required void Function(String? source) pick,
  }) {
    native.MenuItem file(String kind, String title, List<String> extensions) {
      final picked = current?.startsWith('$kind:') ?? false;
      return menuCheck(
        picked
            ? '$title: ${current!.split(Platform.pathSeparator).last}'
            : '$title…',
        picked,
        () async {
          final file = await openFile(
            acceptedTypeGroups: [
              XTypeGroup(label: title, extensions: extensions),
            ],
          );
          if (file != null) pick('$kind:${file.path}');
        },
      );
    }

    return menuSubmenu(label, [
      menuCheck('AVD default', current == null, () => pick(null)),
      menuCheck('Emulated', current == 'emulated', () => pick('emulated')),
      if (back)
        menuCheck(
          'Virtual scene',
          current == 'virtualscene',
          () => pick('virtualscene'),
        ),
      menuCheck('Off', current == 'none', () => pick('none')),
      for (final cam in webcams)
        menuCheck(cam.name, current == cam.id, () => pick(cam.id)),
      file('image', 'Image', const ['png', 'jpg', 'jpeg']),
      file('video', 'Video', const ['mp4', 'mov', 'webm']),
    ]);
  }

  return [
    side(
      'Back camera',
      settings.cameraBack,
      back: true,
      pick: (v) => set((s) => s.copyWith(cameraBack: () => v)),
    ),
    side(
      'Front camera',
      settings.cameraFront,
      back: false,
      pick: (v) => set((s) => s.copyWith(cameraFront: () => v)),
    ),
  ];
}

/// Camera of an iOS simulator: pick a host webcam, image or video to feed
/// it, then launch an app reading that feed (serve-sim's camera injector).
List<native.MenuItem> _simCameraItems(
  BuildContext context,
  Device device,
  _SimCameraState state,
) {
  final devices = context.read<DevicesCubit>();
  final current = state.current;
  Future<void> guard(String done, Future<void> Function() action) async {
    try {
      await action();
      devices.notify(done);
    } on Object catch (e) {
      final message = e is StateError ? e.message : '$e';
      devices.notify('Camera: $message', error: true);
    }
  }

  void feed(String source, String? arg, String label) => guard(
    'Simulator camera: $label',
    () => SimCamera.setSource(device.id, source, arg),
  );

  native.MenuItem file(String kind, String title, List<String> extensions) {
    final picked = current?.source == kind;
    return menuCheck(
      picked
          ? '$title: ${current!.arg!.split(Platform.pathSeparator).last}'
          : '$title…',
      picked,
      () async {
        final file = await openFile(
          acceptedTypeGroups: [
            XTypeGroup(label: title, extensions: extensions),
          ],
        );
        if (file != null) feed(kind, file.path, file.name);
      },
    );
  }

  return [
    for (final cam in state.webcams)
      menuCheck(
        cam.name,
        current?.source == 'webcam' && current?.arg == cam.id,
        () => feed('webcam', cam.id, cam.name),
      ),
    file('image', 'Image', const ['png', 'jpg', 'jpeg', 'heic']),
    file('video', 'Video', const ['mp4', 'mov', 'm4v']),
    if (current != null) ...[
      menuSubmenu('Open app with camera', [
        for (final app in state.apps)
          menuItem(
            app.name,
            () => guard(
              'Launched ${app.name} with the camera',
              () => SimCamera.launch(getIt<IosAutomation>(), device, app.id),
            ),
          ),
        if (state.apps.isEmpty) menuItem('No apps installed', null),
      ]),
      menuItem(
        'Turn off camera',
        () => guard('Simulator camera off', () => SimCamera.stop(device.id)),
      ),
    ],
  ];
}

/// Device frame, and the scrcpy options of an Android stream; they apply
/// the next time the stream opens.
List<native.MenuItem> _streamItems(
  BuildContext context,
  Device device,
  void Function(DeviceSettings Function(DeviceSettings)) set,
) {
  final streams = context.read<StreamsCubit>();
  final settings = context.read<DeviceSettingsCubit>().of(device);
  return [
    menuCheck(
      'Show device frame',
      settings.showFrame,
      () => set((s) => s.copyWith(showFrame: !s.showFrame)),
    ),
    if (device.os == DeviceOs.android)
      menuSubmenu('scrcpy options', [
        menuSubmenu('Resolution', [
          for (final size in const [720, 1080, 1280, 1920, 0])
            menuCheck(
              size == 0 ? 'Native' : '$size px',
              settings.maxSize == size,
              () => set((s) => s.copyWith(maxSize: size)),
            ),
        ]),
        menuSubmenu('Frame rate', [
          for (final fps in const [30, 60, 120])
            menuCheck(
              '$fps fps',
              settings.maxFps == fps,
              () => set((s) => s.copyWith(maxFps: fps)),
            ),
        ]),
        menuSubmenu('Bit rate', [
          for (final mbps in const [4, 8, 16, 24])
            menuCheck(
              '$mbps Mbps',
              settings.bitRateMbps == mbps,
              () => set((s) => s.copyWith(bitRateMbps: mbps)),
            ),
        ]),
        menuCheck(
          'Show touches',
          settings.showTouches,
          () => set((s) => s.copyWith(showTouches: !s.showTouches)),
        ),
        menuCheck(
          'Stay awake',
          settings.stayAwake,
          () => set((s) => s.copyWith(stayAwake: !s.stayAwake)),
        ),
        menuCheck(
          'Turn device screen off',
          settings.turnScreenOff,
          () => set((s) => s.copyWith(turnScreenOff: !s.turnScreenOff)),
        ),
        menuCheck(
          'Screen off when stream closes',
          settings.powerOffOnClose,
          () => set((s) => s.copyWith(powerOffOnClose: !s.powerOffOnClose)),
        ),
        if (streams.sessionFor(device.id) != null)
          menuItem('Restart stream with new options', () async {
            await streams.closeStream(device.id);
            await streams.open(device);
          }),
      ]),
  ];
}

/// Wipe data and Delete; only when shut down.
List<native.MenuItem> _deleteItems(BuildContext context, Device device) {
  if (device.state != DeviceState.shutdown) {
    return [menuItem('Wipe data / Delete (shut down first)', null)];
  }
  final devices = context.read<DevicesCubit>();
  return [
    menuItem('Wipe data', () => devices.wipeData(device)),
    menuItem('Delete “${device.name}”', () => devices.delete(device)),
  ];
}
