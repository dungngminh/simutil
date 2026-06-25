import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/android_launch_dialog.dart';
import 'package:simutil/components/app_header.dart';
import 'package:simutil/components/app_status_bar.dart';
import 'package:simutil/components/device_detail_panel.dart';
import 'package:simutil/components/device_list_component.dart';
import 'package:simutil/components/error_dialog.dart';
import 'package:simutil/components/input_dialog.dart';
import 'package:simutil/components/simutil_theme.dart';
import 'package:simutil/components/success_dialog.dart';
import 'package:simutil/models/android_quick_launch_option.dart';
import 'package:simutil/models/app_settings.dart';
import 'package:simutil/models/device.dart';
import 'package:simutil/models/device_os.dart';
import 'package:simutil/models/plugin_config.dart';
import 'package:simutil/plugins/adb_tools/adb_tools_dialog.dart';
import 'package:simutil/plugins/adb_tools/qr_connect_dialog.dart';
import 'package:simutil/plugins/adb_tools/wireless_pairing/wireless_pairing_dialog.dart';
import 'package:simutil/plugins/logcat/logcat_dialog.dart';
import 'package:simutil/plugins/registry/command_menu_dialog.dart';
import 'package:simutil/plugins/registry/plugin_menu_dialog.dart';
import 'package:simutil/services/service_locator.dart';
import 'package:simutil/utils/constant.dart';

class SimutilApp extends StatefulComponent {
  const SimutilApp({super.key});

  @override
  State<SimutilApp> createState() => _SimutilAppState();
}

class _SimutilAppState extends State<SimutilApp> {
  static const _refreshTimeout = Duration(seconds: 15);

  final _di = ServiceLocator.instance;

  AppSettings _settings = const AppSettings();
  TuiThemeData _themeData = TuiThemeData.dark;

  List<Device> _androidDevices = [];
  List<Device> _androidEmulators = [];
  List<Device> _iosSimulators = [];
  List<Device> _iosDevices = [];

  bool _loadingAndroidDevices = true;
  bool _loadingAndroidEmulators = true;
  bool _loadingIosSimulators = true;
  bool _loadingIosDevices = true;
  bool _isRefreshing = false;

  String _statusMessage = 'Loading devices…';

  int _androidDeviceSelectedIndex = 0;
  int _androidEmulatorSelectedIndex = 0;
  int _iosSimulatorSelectedIndex = 0;
  int _iosDeviceSelectedInded = 0;

  /// Active panel: 'android' | 'ios' | 'android-emulators' | 'ios-simulators'
  String _focusKey = 'android';

  List<String> focusPanelScopes = [
    'android',
    'android-emulators',
    'ios',
    'ios-simulators',
  ];

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await _di.init();
    _loadSettings();
    await _di.pluginRegistry.load();
    await _refreshDevices();
    _initRefreshTimer();
  }

  void _initRefreshTimer() {
    _refreshTimer = Timer.periodic(kReloadInterval, (_) {
      _refreshDevices(silent: true);
    });
  }

  Future<void> _loadSettings() async {
    final settings = await _di.settingsService.load();
    setState(() {
      _settings = settings;
      _themeData = SimutilTheme.resolveTheme(settings.themeName);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _di.dispose();
    super.dispose();
  }

  Future<void> _refreshDevices({bool silent = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    if (!silent) {
      setState(() {
        _loadingAndroidDevices = true;
        _loadingAndroidEmulators = true;
        _loadingIosSimulators = true;
        _loadingIosDevices = true;
        _statusMessage = 'Refreshing devices...';
      });
    }

    try {
      final shouldLoadIos = Platform.isMacOS;
      final androidDevices = await _loadDevicesWithTimeout(
        label: 'Android devices',
        silent: silent,
        loader: _di.adbService.getPhysicalDevices,
      );
      final androidEmulators = await _loadDevicesWithTimeout(
        label: 'Android emulators',
        silent: silent,
        loader: _di.adbService.getSimulators,
      );
      final iosSimulators = shouldLoadIos
          ? await _loadDevicesWithTimeout(
              label: 'iOS simulators',
              silent: silent,
              loader: _di.simctlService.getSimulators,
            )
          : <Device>[];
      final iosDevices = shouldLoadIos
          ? await _loadDevicesWithTimeout(
              label: 'iOS devices',
              silent: silent,
              loader: _di.simctlService.getPhysicalDevices,
            )
          : <Device>[];

      setState(() {
        _androidDevices = androidDevices;
        _androidEmulators = androidEmulators;
        _iosSimulators = iosSimulators;
        _iosDevices = iosDevices;
        _loadingAndroidDevices = false;
        _loadingAndroidEmulators = false;
        _loadingIosSimulators = false;
        _loadingIosDevices = false;
        // Make sure index in range
        _androidDeviceSelectedIndex = _androidDevices.isEmpty
            ? 0
            : _androidDeviceSelectedIndex.clamp(0, _androidDevices.length - 1);
        _androidEmulatorSelectedIndex = _androidEmulators.isEmpty
            ? 0
            : _androidEmulatorSelectedIndex.clamp(
                0,
                _androidEmulators.length - 1,
              );
        _iosDeviceSelectedInded = _iosDevices.isEmpty
            ? 0
            : _iosDeviceSelectedInded.clamp(0, _iosDevices.length - 1);
        _iosSimulatorSelectedIndex = _iosSimulators.isEmpty
            ? 0
            : _iosSimulatorSelectedIndex.clamp(0, _iosSimulators.length - 1);
        // By default always keep focus on simulators / emulator list
        final hasAndroidDevices = _androidDevices.isNotEmpty;
        final hasIosDevices = _iosDevices.isNotEmpty;

        final isFocusingOnEmptyAndroidDevicesPanel =
            _focusKey == 'android' && !hasAndroidDevices;
        final isFocusingOnEmptyIosDevicesPanel =
            _focusKey == 'ios' && !hasIosDevices;

        final isFocusingOnEmptyPhysicalDevicesPanel =
            isFocusingOnEmptyAndroidDevicesPanel ||
            isFocusingOnEmptyIosDevicesPanel;

        if (isFocusingOnEmptyPhysicalDevicesPanel) {
          _focusKey = 'android-emulators';
          _statusMessage = _buildIdleStatusMessage();
        }
        focusPanelScopes = [
          if (hasAndroidDevices) 'android',
          'android-emulators',
          if (hasIosDevices) 'ios',
          'ios-simulators',
        ];

        _statusMessage = _buildIdleStatusMessage();
      });
    } finally {
      _isRefreshing = false;
    }
  }

  Future<List<Device>> _loadDevicesWithTimeout({
    required String label,
    required bool silent,
    required Future<List<Device>> Function() loader,
  }) async {
    try {
      if (!silent) {
        setState(() {
          _statusMessage = 'Refreshing $label...';
        });
      }
      return await loader().timeout(_refreshTimeout);
    } on TimeoutException {
      log('Timed out while loading $label after $_refreshTimeout');
      if (!silent) {
        setState(() {
          _statusMessage = 'Timed out while refreshing $label';
        });
      }
      return <Device>[];
    } catch (e, st) {
      log('Failed to load $label: $e\n$st');
      if (!silent) {
        setState(() {
          _statusMessage = 'Failed to refresh $label';
        });
      }
      return <Device>[];
    }
  }

  String _buildIdleStatusMessage() {
    return switch (_focusKey) {
      'android' => _buildIdleStatusMessageForAndroidDevices(),
      'android-emulators' => _buildIdleStatusMessageForAndroidEmulators(),
      'ios' => _buildIdleStatusMessageForIos(),
      'ios-simulators' => _buildIdleStatusMessageForIosSimulators(),
      _ => _buildIdleStatusMessageForIosSimulators(),
    };
  }

  String _buildIdleStatusMessageForIosSimulators() {
    if (_iosSimulators.isEmpty) {
      return 'Edit config: e | ADB Tools: n | Refresh: r | Switch: <tab> | Quit: q';
    }
    final device = _iosSimulators[_iosSimulatorSelectedIndex];
    final parts = <String>[
      'Launch: <space> or <enter>',
      if (device.isRunning) 'Shutdown: t',
      'Plugins: p',
      'Edit config: e',
      'ADB Tools: n',
      'Refresh: r',
      'Switch: <tab>',
      'Quit: q',
    ];
    return parts.join(' | ');
  }

  String _buildIdleStatusMessageForIos() {
    final parts = <String>[
      'Plugins: p',
      'Edit config: e',
      'ADB Tools: n',
      'Refresh: r',
      'Switch: <tab>',
      'Quit: q',
    ];
    return parts.join(' | ');
  }

  String _buildIdleStatusMessageForAndroidEmulators() {
    if (_androidEmulators.isEmpty) {
      return 'Edit config: e | ADB Tools: n | Refresh: r | Switch: <tab> | Quit: q';
    }
    final device = _androidEmulators[_androidEmulatorSelectedIndex];
    final parts = <String>[
      'Launch: <space>',
      'Launch with option: <enter>',
      if (device.isRunning) 'Shutdown: t',
      if (device.isRunning) 'Logcat: l',
      'Plugins: p',
      'Edit config: e',
      'ADB Tools: n',
      'Refresh: r',
      'Switch: <tab>',
      'Quit: q',
    ];
    return parts.join(' | ');
  }

  String _buildIdleStatusMessageForAndroidDevices() {
    final parts = <String>[
      'Plugins: p',
      'Logcat: l',
      'Edit config: e',
      'ADB Tools: n',
      'Refresh: r',
      'Switch: <tab>',
      'Quit: q',
    ];
    return parts.join(' | ');
  }

  Device? get _currentSelectedDevice {
    if (_focusKey == 'android' && _androidDevices.isNotEmpty) {
      return _androidDevices[_androidDeviceSelectedIndex];
    }
    if (_focusKey == 'android-emulators' && _androidEmulators.isNotEmpty) {
      return _androidEmulators[_androidEmulatorSelectedIndex];
    }
    if (_focusKey == 'ios' && _iosDevices.isNotEmpty) {
      return _iosDevices[_iosDeviceSelectedInded];
    }
    if (_focusKey == 'ios-simulators' && _iosSimulators.isNotEmpty) {
      return _iosSimulators[_iosSimulatorSelectedIndex];
    }
    return null;
  }

  bool _handleGlobalKey(KeyboardEvent event) {
    switch (event.logicalKey) {
      case LogicalKey.tab || LogicalKey.arrowRight:
        setState(() {
          final currentIndex = focusPanelScopes.indexOf(_focusKey);
          final nextIndex = (currentIndex + 1) % focusPanelScopes.length;
          _focusKey = focusPanelScopes[nextIndex];
          _statusMessage = _buildIdleStatusMessage();
        });
        return true;
      case LogicalKey.arrowLeft:
        setState(() {
          final currentIndex = focusPanelScopes.indexOf(_focusKey);
          final nextIndex = currentIndex == 0
              ? focusPanelScopes.length - 1
              : (currentIndex - 1) % focusPanelScopes.length;
          _focusKey = focusPanelScopes[nextIndex];
          _statusMessage = _buildIdleStatusMessage();
        });
        return true;
      case LogicalKey.keyR:
        _refreshDevices();
        return true;
      case LogicalKey.keyN:
        _showAdbTools();
        return true;
      case LogicalKey.keyP:
        _showPluginMenu();
        return true;
      case LogicalKey.keyE:
        _openSettingsFile();
        return true;
      case LogicalKey.keyQ:
        shutdownApp();
        return true;
      default:
        final character = event.character;
        if (character != null &&
            character.length == 1 &&
            !event.modifiers.hasAnyModifier) {
          return _handlePluginShortcut(character);
        }
        return false;
    }
  }

  Future<void> _showAdbTools() async {
    final option = await showAdbToolsDialog(context);
    if (option == null) return;

    switch (option) {
      case AdbToolOption.connectViaIp:
        await _handleAdbConnect();
        break;
      case AdbToolOption.pairWithPairingCode:
        await _handleWirelessPairing();
        break;
      case AdbToolOption.pairWithQrCode:
        await _handleQrConnect();
        break;
    }
  }

  Future<void> _handleAdbConnect() async {
    final host = await showInputDialog(
      context: context,
      title: 'ADB Connect',
      label: 'Enter device IP:Port',
      hint: 'e.g., 192.168.1.100:5555',
    );

    if (host == null || host.isEmpty) return;

    setState(() => _statusMessage = 'Connecting to $host…');

    final result = await _di.adbService.connectDevice(host);

    if (result.success) {
      await showSuccessDialog(
        context: context,
        title: 'Connected',
        message: result.message,
      );
      await _refreshDevices();
    } else {
      await showErrorDialog(
        context,
        title: 'Connection Failed',
        message: result.message,
      );
      setState(() => _statusMessage = 'Connection failed');
    }
  }

  Future<void> _handleWirelessPairing() async {
    final request = await showWirelessConnectDialog(
      context: context,
      discoveryService: _di.wifiDiscoveryService,
    );

    if (request == null) return;

    if (request.pairingCode != null) {
      setState(() => _statusMessage = 'Pairing with ${request.host}…');

      final pairResult = await _di.adbService.pairDevice(
        request.host,
        request.pairingCode!,
      );

      if (!pairResult.success) {
        showErrorDialog(
          context,
          title: 'Pairing Failed',
          message: pairResult.message,
        );
        return;
      }

      await showSuccessDialog(
        context: context,
        title: 'Paired Successfully',
        message: pairResult.message,
      );
      _refreshDevices();
    }
  }

  Future<void> _handleQrConnect() async {
    await showQrConnectDialog(context);
  }

  Future<void> _onDeviceDefaultLaunch(Device device) async {
    try {
      if (device.type.isPhysical) return;
      setState(() => _statusMessage = 'Launching ${device.name}…');
      if (device.os == DeviceOs.android) {
        await _di.adbService.launchDevice(
          deviceId: device.id,
          additionalArgs: AndroidQuickLaunchOption.normal.args,
        );
      } else {
        await _di.simctlService.launchDevice(deviceId: device.id);
      }
      setState(() => _statusMessage = '${device.name} launched!');
      Future.delayed(
        kReloadAfterActionInterval,
        () => _refreshDevices(silent: true),
      );
    } catch (e) {
      setState(() => _statusMessage = 'Failed to launch ${device.name}: $e');
    }
  }

  Future<void> _onDeviceShowOptions(Device device) async {
    try {
      if (device.os == DeviceOs.android) {
        final option = await showLaunchDialog(context: context, device: device);
        if (option != null) {
          setState(() => _statusMessage = 'Launching ${device.name}…');
          await _di.adbService.launchDevice(
            deviceId: device.id,
            additionalArgs: option.args,
          );
          setState(() => _statusMessage = '${device.name} launched!');
          Future.delayed(
            kReloadAfterActionInterval,
            () => _refreshDevices(silent: true),
          );
        }
      } else {
        await _onDeviceDefaultLaunch(device);
      }
    } catch (e) {
      setState(() => _statusMessage = 'Failed to launch ${device.name}: $e');
    }
  }

  Future<void> _onDeviceShutdownRequested(Device device) async {
    try {
      if (device.type.isPhysical || !device.isRunning) return;
      setState(() => _statusMessage = 'Shutting down ${device.name}…');
      if (device.os == DeviceOs.android) {
        await _di.adbService.shutdownSimulator(deviceId: device.id);
      } else {
        await _di.simctlService.shutdownSimulator(deviceId: device.id);
      }
      setState(() => _statusMessage = '${device.name} shut down!');
      Future.delayed(
        kReloadAfterActionInterval,
        () => _refreshDevices(silent: true),
      );
    } catch (e) {
      setState(() => _statusMessage = 'Failed to shut down ${device.name}: $e');
    }
  }

  Future<void> _onDeviceLogcatRequested(Device device) async {
    await showLogcatDialog(
      context: context,
      device: device,
      adbPath: _di.adbService.adbPath,
    );
  }

  bool _handlePluginShortcut(String key) {
    final device = _currentSelectedDevice;
    final commandRef = _di.pluginRegistry.commandByShortcut(key, device);
    if (commandRef != null) {
      _runPluginCommand(commandRef.plugin, commandRef.command, device);
      return true;
    }
    final plugin = _di.pluginRegistry.pluginByShortcut(key, device);
    if (plugin != null) {
      _openCommandMenuForPlugin(plugin, device);
      return true;
    }
    return false;
  }

  Future<void> _openSettingsFile() async {
    await _di.settingsService.openInEditor();
    if (!mounted) return;
    setState(
      () => _statusMessage =
          'Opened ${_di.settingsService.configFilePath} (changes apply on restart)',
    );
  }

  Future<void> _showPluginMenu() async {
    final device = _currentSelectedDevice;
    final plugins = _di.pluginRegistry.pluginsForDevice(device);
    if (plugins.isEmpty) {
      setState(() => _statusMessage = 'No plugins available for this device');
      return;
    }

    final plugin = await showPluginMenuDialog(
      context: context,
      plugins: plugins,
    );
    if (plugin == null) return;

    await _openCommandMenuForPlugin(plugin, device);
  }

  Future<void> _openCommandMenuForPlugin(
    PluginConfig plugin,
    Device? device,
  ) async {
    final commands = plugin.commandsFor(device);
    if (commands.isEmpty) {
      setState(
        () => _statusMessage = 'No commands available for ${plugin.label}',
      );
      return;
    }

    final command = await showCommandMenuDialog(
      context: context,
      title: plugin.label,
      commands: commands,
    );
    if (command == null) return;

    await _runPluginCommand(plugin, command, device);
  }

  Future<void> _runPluginCommand(
    PluginConfig plugin,
    PluginCommandConfig command,
    Device? device,
  ) async {
    setState(() => _statusMessage = 'Checking ${command.label}…');
    final available = await _di.pluginRunner.isAvailable(plugin, command);
    if (!available) {
      setState(
        () => _statusMessage =
            '${command.command} not found. Please install it first.',
      );
      return;
    }

    setState(() => _statusMessage = 'Launching ${command.label}…');
    final result = await _di.pluginRunner.run(command, device);
    setState(() => _statusMessage = result.message);
  }

  @override
  Component build(BuildContext context) {
    return TuiTheme(data: _themeData, child: _buildShell(context));
  }

  Component _buildShell(BuildContext context) {
    return Focusable(
      focused: true,
      onKeyEvent: _handleGlobalKey,
      child: Column(
        children: [
          AppHeader(themeName: _settings.themeName),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      if (_androidDevices.isNotEmpty)
                        Expanded(child: _androidDevicesPanel()),
                      Expanded(flex: 2, child: _androidEmulatorsPanel()),
                      if (_iosDevices.isNotEmpty)
                        Expanded(child: _iosDevicePanel()),
                      Expanded(flex: 2, child: _iosSimulatorsPanel()),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: DeviceDetailPanel(device: _currentSelectedDevice),
                ),
              ],
            ),
          ),
          AppStatusBar(message: _statusMessage),
        ],
      ),
    );
  }

  Component _androidDevicesPanel() {
    final focused = _focusKey == 'android';
    final st = context.simutilTheme;
    return Container(
      decoration: focused
          ? st.focusedPanel('Android Devices')
          : st.unfocusedPanel('Android Devices'),
      child: DeviceListComponent(
        devices: _androidDevices,
        focused: focused,
        isLoading: _loadingAndroidDevices,
        selectedIndex: _androidDeviceSelectedIndex,
        emptyMessage: 'No Android devices found',
        onSelectionChanged: (i) => setState(() {
          _androidDeviceSelectedIndex = i;
        }),
        onDeviceLaunchRequested: null,
        onDeviceShowOptions: null,
        onDeviceLogcatRequested: _onDeviceLogcatRequested,
      ),
    );
  }

  Component _androidEmulatorsPanel() {
    final focused = _focusKey == 'android-emulators';
    final st = context.simutilTheme;
    return Container(
      decoration: focused
          ? st.focusedPanel('Android Emulators')
          : st.unfocusedPanel('Android Emulators'),
      child: DeviceListComponent(
        devices: _androidEmulators,
        focused: focused,
        isLoading: _loadingAndroidEmulators,
        selectedIndex: _androidEmulatorSelectedIndex,
        onDeviceShutdownRequested: _onDeviceShutdownRequested,
        emptyMessage: 'No Android emulators found',
        onSelectionChanged: (i) => setState(() {
          _androidEmulatorSelectedIndex = i;
          _statusMessage = _buildIdleStatusMessage();
        }),
        onDeviceLaunchRequested: _onDeviceDefaultLaunch,
        onDeviceShowOptions: _onDeviceShowOptions,
        onDeviceLogcatRequested: _onDeviceLogcatRequested,
      ),
    );
  }

  Component _iosSimulatorsPanel() {
    final st = context.simutilTheme;
    final focused = _focusKey == 'ios-simulators';
    final isSupported = Platform.isMacOS;
    if (!isSupported) {
      return Container(
        decoration: focused
            ? st.focusedPanel('iOS Simulators')
            : st.unfocusedPanel('iOS Simulators'),
        child: Center(
          child: Text(
            'iOS simulators are only supported on macOS',
            style: st.dimmed,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Container(
      decoration: focused
          ? st.focusedPanel('iOS Simulators')
          : st.unfocusedPanel('iOS Simulators'),
      child: DeviceListComponent(
        devices: _iosSimulators,
        focused: focused,
        isLoading: _loadingIosSimulators,
        selectedIndex: _iosSimulatorSelectedIndex,
        loadingMessage: 'Loading devices...\nFirst load may take a while',
        emptyMessage: 'No iOS simulators found',
        onSelectionChanged: (i) => setState(() {
          _iosSimulatorSelectedIndex = i;
          _statusMessage = _buildIdleStatusMessage();
        }),
        onDeviceLaunchRequested: _onDeviceDefaultLaunch,
        onDeviceShowOptions: _onDeviceShowOptions,
        onDeviceShutdownRequested: _onDeviceShutdownRequested,
      ),
    );
  }

  Component _iosDevicePanel() {
    final st = context.simutilTheme;
    final focused = _focusKey == 'ios';
    return Container(
      decoration: focused
          ? st.focusedPanel('iOS Devices')
          : st.unfocusedPanel('iOS Devices'),
      child: DeviceListComponent(
        devices: _iosDevices,
        focused: focused,
        isLoading: _loadingIosDevices,
        selectedIndex: _iosDeviceSelectedInded,
        emptyMessage: 'No iOS devices found',
        onSelectionChanged: (i) => setState(() => _iosDeviceSelectedInded = i),
        onDeviceLaunchRequested: _onDeviceDefaultLaunch,
        onDeviceShowOptions: _onDeviceShowOptions,
      ),
    );
  }
}
