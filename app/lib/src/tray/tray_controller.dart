import 'package:flutter/services.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../devices/devices_cubit.dart';
import '../devices/devices_state.dart';

/// Tray icon whose menu lists devices; clicking a stopped emulator or
/// simulator boots it. Also hides the window on close instead of quitting.
class TrayController with WindowListener {
  TrayController(this._devices, {required this.onQuit});

  final DevicesCubit _devices;

  /// Called by the Quit item, after the tray icon is removed.
  final Future<void> Function() onQuit;

  TrayIcon? _trayIcon;
  Menu? _menu;
  void Function()? _unsubscribe;

  /// Shown in the menu (click copies it) once the MCP server runs.
  Uri? mcpUrl;

  Future<void> init() async {
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    _trayIcon = TrayIcon.create()!
      ..icon = ImageAsset.fromAsset('assets/tray_icon.png')
      ..setTooltip('SimUtil')
      ..setContextMenuTrigger(ContextMenuTrigger.clicked)
      ..setVisible(true);
    _unsubscribe = _devices.state.subscribe(_rebuildMenu);
  }

  void _rebuildMenu(DevicesState state) {
    final menu = Menu.create()!;
    final devices = state.all;
    if (devices.isEmpty) {
      menu.addItem(
        _item(
          state.loading ? 'Loading devices…' : 'No devices',
          enabled: false,
        ),
      );
    }
    for (final device in devices) {
      menu.addItem(_deviceItem(device));
    }
    menu
      ..addSeparator()
      ..addItem(_item('Show SimUtil', onClick: showWindow))
      ..addItem(_item('Refresh', onClick: _devices.refresh));
    if (mcpUrl case final url?) {
      menu.addItem(
        _item(
          'Copy MCP URL ($url)',
          onClick: () => Clipboard.setData(ClipboardData(text: '$url')),
        ),
      );
    }
    menu
      ..addSeparator()
      ..addItem(_item('Quit SimUtil', onClick: _quit));

    _trayIcon?.setContextMenu(menu);
    _menu?.dispose();
    _menu = menu;
  }

  MenuItem _deviceItem(Device device) {
    final canLaunch =
        !device.type.isPhysical && device.state == DeviceState.shutdown;
    final icon = device.os == DeviceOs.android ? '🤖' : '';
    return _item(
      '$icon ${device.name} · ${device.state.label}',
      enabled: canLaunch,
      onClick: () => _devices.launch(device),
    );
  }

  MenuItem _item(
    String label, {
    bool enabled = true,
    Future<void> Function()? onClick,
  }) {
    final item = MenuItem.createWithLabelAndType(label, MenuItemType.normal)!
      ..isEnabled = enabled;
    if (onClick != null) {
      item.addListener((event) {
        if (event is MenuItemClickedEvent) return onClick();
      });
    }
    return item;
  }

  /// Brings the main window to the front.
  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _quit() async {
    _unsubscribe?.call();
    windowManager.removeListener(this);
    _trayIcon?.dispose();
    _menu?.dispose();
    await onQuit();
  }

  @override
  void onWindowClose() => windowManager.hide();
}
