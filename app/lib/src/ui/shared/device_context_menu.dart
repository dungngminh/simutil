import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:tray_manager/tray_manager.dart' as native;

import '../../devices/devices_cubit.dart';
import '../../settings/device_settings_cubit.dart';
import '../../settings/recordings_dir.dart';
import '../../settings/view_settings_cubit.dart';
import '../../stream/streams_cubit.dart';
import 'device_actions.dart';

/// Opens a native context menu for [device] at the cursor: its actions plus
/// per-device settings.
void showDeviceContextMenu(BuildContext context, Device device) {
  final devices = context.read<DevicesCubit>();
  final streams = context.read<StreamsCubit>();
  final settingsCubit = context.read<DeviceSettingsCubit>();
  final settings = settingsCubit.of(device);
  final globalHeadless = context.read<ViewSettingsCubit>().stateValue.headless;
  final session = streams.sessionFor(device.id);
  void set(DeviceSettings Function(DeviceSettings) change) =>
      settingsCubit.update(device, change);

  final menu = native.Menu.create()!;
  for (final action in deviceActions(context, device, devices.stateValue)) {
    menu.addItem(_item(action.label, action.onPressed));
  }
  if (session != null) {
    menu
      ..addItem(
        _item(
          session.isRecording ? 'Stop recording' : 'Record',
          () => streams.toggleRecording(device.id, recordingsDirectory()),
        ),
      )
      ..addItem(_item('Close stream', () => streams.closeStream(device.id)));
    if (session.status case SessionLive(inputBlocked: true)) {
      menu.addItem(_item('Repair input (restarts apps)', session.repairInput));
    }
  }

  if (!device.type.isPhysical) {
    menu
      ..addSeparator()
      ..addItem(
        _check(
          'Start headless',
          settings.headless ?? globalHeadless,
          () => set(
            (s) => s.copyWith(headless: () => !(s.headless ?? globalHeadless)),
          ),
        ),
      );
    if (device.os == DeviceOs.android) {
      menu.addItem(
        _check(
          'Cold boot',
          settings.coldBoot,
          () => set((s) => s.copyWith(coldBoot: !s.coldBoot)),
        ),
      );
    }
  }

  if (device.os == DeviceOs.android) {
    menu
      ..addSeparator()
      ..addItem(
        _submenu('Stream resolution', [
          for (final size in const [720, 1080, 1280, 1920, 0])
            _check(
              size == 0 ? 'Native' : '$size px',
              settings.maxSize == size,
              () => set((s) => s.copyWith(maxSize: size)),
            ),
        ]),
      )
      ..addItem(
        _submenu('Stream frame rate', [
          for (final fps in const [30, 60, 120])
            _check(
              '$fps fps',
              settings.maxFps == fps,
              () => set((s) => s.copyWith(maxFps: fps)),
            ),
        ]),
      )
      ..addItem(
        _submenu('Stream bit rate', [
          for (final mbps in const [4, 8, 16, 24])
            _check(
              '$mbps Mbps',
              settings.bitRateMbps == mbps,
              () => set((s) => s.copyWith(bitRateMbps: mbps)),
            ),
        ]),
      );
    if (session != null) {
      menu.addItem(
        _item('Restart stream with new settings', () async {
          await streams.closeStream(device.id);
          await streams.open(device);
        }),
      );
    }
  }

  menu.open(
    native.PositioningStrategy.cursorPosition()!,
    native.Placement.bottomStart,
  );
}

native.MenuItem _item(String label, Future<void> Function()? onClick) {
  final item = native.MenuItem.createWithLabelAndType(
    label,
    native.MenuItemType.normal,
  )!;
  if (onClick != null) {
    item.addListener((event) {
      if (event is native.MenuItemClickedEvent) return onClick();
    });
  } else {
    item.isEnabled = false;
  }
  return item;
}

native.MenuItem _check(String label, bool checked, void Function() onClick) {
  final item =
      native.MenuItem.createWithLabelAndType(
          label,
          native.MenuItemType.checkbox,
        )!
        ..state = checked
            ? native.MenuItemState.checked
            : native.MenuItemState.unchecked;
  item.addListener((event) {
    if (event is native.MenuItemClickedEvent) onClick();
  });
  return item;
}

native.MenuItem _submenu(String label, List<native.MenuItem> items) {
  final submenu = native.Menu.create()!;
  items.forEach(submenu.addItem);
  return native.MenuItem.createWithLabelAndType(
    label,
    native.MenuItemType.submenu,
  )!..submenu = submenu;
}
