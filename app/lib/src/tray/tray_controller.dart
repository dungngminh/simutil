import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_app/src/devices/devices_state.dart';
import 'package:simutil_app/src/settings/device_settings_cubit.dart';
import 'package:simutil_app/src/settings/view_settings_cubit.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_apple/simutil_apple.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Tray icon whose menu lists devices by group, each with its actions
/// (stream / start / shut down). Also hides the window on close instead of
/// quitting.
class TrayController with WindowListener {
  TrayController({
    required DevicesCubit devices,
    required StreamsCubit streams,
    required DeviceSettingsCubit deviceSettings,
    required ViewSettingsCubit viewSettings,
    required XcodeCacheService xcodeCache,
    required this.onQuit,
  }) : _devices = devices,
       _streams = streams,
       _deviceSettings = deviceSettings,
       _viewSettings = viewSettings,
       _xcodeCache = xcodeCache;

  final DevicesCubit _devices;
  final StreamsCubit _streams;
  final DeviceSettingsCubit _deviceSettings;
  final ViewSettingsCubit _viewSettings;
  final XcodeCacheService _xcodeCache;

  /// Outcome of the last DerivedData clear, shown in its submenu.
  String? _derivedDataMessage;

  /// Called by the Quit item, after the tray icon is removed.
  final Future<void> Function() onQuit;

  TrayIcon? _trayIcon;
  Image? _icon;
  ListenerId? _clickListener;

  /// Menus of the menu shown now, kept alive until the next rebuild.
  List<Menu> _menus = [];
  final _unsubscribes = <void Function()>[];

  Uri? _mcpUrl;

  /// Shown in the menu (click copies it) once the MCP server runs.
  set mcpUrl(Uri? url) {
    _mcpUrl = url;
    _rebuildMenu();
  }

  Future<void> init() async {
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    final tray = _trayIcon = TrayIcon.create()!;
    // macOS tints the one-color template for light / dark menu bars; other
    // trays show the colored mark.
    _icon = ImageAsset.fromAsset(
      Platform.isMacOS ? 'assets/tray_icon.png' : 'assets/tray_icon_color.png',
    );
    tray
      ..icon = _icon
      ..isIconTemplate = Platform.isMacOS
      ..setTooltip('SimUtil')
      ..setContextMenuTrigger(ContextMenuTrigger.clicked)
      ..setVisible(true);
    // Without an icon the status item would be zero-width and unclickable.
    if (_icon == null) tray.setTitle('SimUtil');
    // nativeapi wires the native click handler (which opens the context
    // menu for ContextMenuTrigger.clicked) only once a listener exists.
    _clickListener = tray.addListener((_) {});
    _unsubscribes
      ..add(_devices.state.subscribe((_) => _rebuildMenu()))
      ..add(_streams.state.subscribe((_) => _rebuildMenu()));
  }

  void _rebuildMenu() {
    final tray = _trayIcon;
    if (tray == null) return;
    final menus = <Menu>[];
    final menu = _menu(menus);
    final state = _devices.stateValue;

    final groups = [
      ('Android emulators', state.androidEmulators),
      ('iOS simulators', state.iosSimulators),
      ('Android devices', state.androidDevices),
      ('iOS devices', state.iosDevices),
    ];
    if (groups.every((g) => g.$2.isEmpty)) {
      menu.addItem(
        _item(
          state.loading ? 'Loading devices…' : 'No devices',
          enabled: false,
        ),
      );
    }
    for (final (title, devices) in groups) {
      if (devices.isEmpty) continue;
      menu.addItem(_item(title, enabled: false));
      for (final device in devices) {
        menu.addItem(_deviceItem(device, state, menus));
      }
      menu.addSeparator();
    }

    menu
      ..addItem(_item('Show SimUtil', onClick: showWindow))
      ..addItem(_item('Refresh devices', onClick: _devices.refresh));
    if (Platform.isMacOS) {
      // The submenu item is the confirmation: no dialog without the window.
      final confirm = _menu(menus)
        ..addItem(_item('Delete DerivedData', onClick: _clearDerivedData));
      if (_derivedDataMessage case final message?) {
        confirm.addItem(_item(message, enabled: false));
      }
      menu.addItem(_item('Clear Xcode DerivedData…')..submenu = confirm);
    }
    if (_mcpUrl case final url?) {
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

    tray.setContextMenu(menu);
    final old = _menus;
    _menus = menus;
    // Later: an item's own click handler may be what triggered this rebuild.
    Timer.run(() {
      for (final m in old) {
        m.dispose();
      }
    });
  }

  Menu _menu(List<Menu> menus) {
    final menu = Menu.create()!;
    menus.add(menu);
    return menu;
  }

  /// "Pixel 7 · Booted" with a submenu of what can be done with it.
  MenuItem _deviceItem(Device device, DevicesState state, List<Menu> menus) {
    final busy = state.busy.contains(device.id);
    final streaming = _streams.stateValue.isOpen(device.id);
    final actions = <MenuItem>[
      if (busy)
        _item('Working…', enabled: false)
      else ...[
        if (streaming)
          _item('Show stream', onClick: showWindow)
        else if (StreamsCubit.canStream(device))
          _item('Stream', onClick: () => _stream(device)),
        if (!device.type.isPhysical && device.state == DeviceState.shutdown)
          _item(
            _headless(device) ? 'Start and stream' : 'Start',
            onClick: () => _start(device),
          ),
        if (!device.type.isPhysical && device.state == DeviceState.booted)
          _item('Shut down', onClick: () => _stop(device)),
      ],
    ];
    final label = [
      device.name,
      if (streaming) 'streaming' else if (busy) '…' else device.state.label,
    ].join(' · ');
    final item = _item(label, enabled: actions.isNotEmpty);
    if (actions.isNotEmpty) {
      final submenu = _menu(menus);
      actions.forEach(submenu.addItem);
      item.submenu = submenu;
    }
    return item;
  }

  bool _headless(Device device) =>
      _deviceSettings.of(device).headless ?? _viewSettings.stateValue.headless;

  Future<void> _stream(Device device) async {
    await showWindow();
    await _streams.open(device);
  }

  Future<void> _start(Device device) async {
    final settings = _deviceSettings.of(device);
    final headless = _headless(device);
    if (headless) _streams.openWhenBooted(device);
    await _devices.launch(
      device,
      headless: headless,
      coldBoot: settings.coldBoot,
      noAudio: settings.noAudio,
    );
  }

  Future<void> _clearDerivedData() async {
    _derivedDataMessage = 'Clearing…';
    _rebuildMenu();
    _derivedDataMessage = (await _xcodeCache.clearDerivedData()).message;
    _rebuildMenu();
  }

  Future<void> _stop(Device device) async {
    await _streams.closeStream(device.id);
    await _devices.shutdown(device);
  }

  MenuItem _item(
    String label, {
    bool enabled = true,
    FutureOr<void> Function()? onClick,
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
    for (final unsubscribe in _unsubscribes) {
      unsubscribe();
    }
    windowManager.removeListener(this);
    if (_clickListener case final id?) _trayIcon?.removeListener(id);
    _trayIcon?.dispose();
    _trayIcon = null;
    _icon?.dispose();
    for (final m in _menus) {
      m.dispose();
    }
    await onQuit();
  }

  @override
  void onWindowClose() => windowManager.hide();
}
