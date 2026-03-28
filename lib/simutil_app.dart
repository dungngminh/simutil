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
import 'package:simutil/plugins/adb_tools/adb_tools_dialog.dart';
import 'package:simutil/plugins/adb_tools/qr_connect_dialog.dart';
import 'package:simutil/plugins/adb_tools/wireless_pairing_dialog.dart';
import 'package:simutil/services/service_locator.dart';
import 'package:simutil/utils/constant.dart';

class SimutilApp extends StatefulComponent {
  const SimutilApp({super.key});

  @override
  State<SimutilApp> createState() => _SimutilAppState();
}

class _SimutilAppState extends State<SimutilApp> {
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
      final results = await Future.wait([
        _di.adbService.getPhysicalDevices().catchError((e, st) {
          log('Failed to load Android devices: $e');
          return <Device>[];
        }),
        _di.adbService.getSimulators().catchError((e, st) {
          log('Failed to load Android emulators: $e');
          return <Device>[];
        }),
        _di.simctlService.getSimulators().catchError((e, st) {
          log('Failed to load iOS simulators: $e');
          return <Device>[];
        }),
        _di.simctlService.getPhysicalDevices().catchError((e, st) {
          log('Failed to load iOS devices: $e');
          return <Device>[];
        }),
      ]);

      setState(() {
        _androidDevices = results[0];
        _androidEmulators = results[1];
        _iosSimulators = results[2];
        _iosDevices = results[3];
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

        _statusMessage = _buildIdleStatusMessage();

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
      });
    } finally {
      _isRefreshing = false;
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
    final device = _iosSimulators[_iosSimulatorSelectedIndex];
    final parts = <String>[
      'Launch: <space> or <enter>',
      if (device.isRunning) 'Shutdown: t',
      'ADB Tools: n',
      'Refresh: r',
      'Switch: <tab>',
      'Quit: q',
    ];
    return parts.join(' | ');
  }

  String _buildIdleStatusMessageForIos() {
    final parts = <String>[
      'ADB Tools: n',
      'Refresh: r',
      'Switch: <tab>',
      'Quit: q',
    ];
    return parts.join(' | ');
  }

  String _buildIdleStatusMessageForAndroidEmulators() {
    final device = _androidEmulators[_androidEmulatorSelectedIndex];
    final parts = <String>[
      'Launch: <space>',
      'Launch with option: <enter>',
      if (device.isRunning) 'Shutdown: t',
      'ADB Tools: n',
      'Refresh: r',
      'Switch: <tab>',
      'Quit: q',
    ];
    return parts.join(' | ');
  }

  String _buildIdleStatusMessageForAndroidDevices() {
    final parts = <String>[
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
      case LogicalKey.keyS:
        return true;
      case LogicalKey.keyQ:
        exit(0);
      default:
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
      case AdbToolOption.connectViaPairCode:
        await _handleWirelessPairing();
        break;
      case AdbToolOption.connectViaQr:
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
    final input = await showWirelessPairingDialog(context: context);

    if (input == null) return;

    setState(() => _statusMessage = 'Pairing with ${input.host}…');

    final result = await _di.adbService.pairDevice(
      input.host,
      input.pairingCode,
    );

    if (result.success) {
      await showSuccessDialog(
        context: context,
        title: 'Paired Successfully',
        message: '${result.message}\n\nYou can now connect to the device.',
      );

      final connectHost = await showInputDialog(
        context: context,
        title: 'Connect to Device',
        label: 'Enter device IP:Port for connection',
        hint: 'Usually same IP with port 5555',
      );

      if (connectHost != null && connectHost.isNotEmpty) {
        await _handleAdbConnectDirect(connectHost);
      }
    } else {
      await showErrorDialog(
        context,
        title: 'Pairing Failed',
        message: result.message,
      );
      setState(() => _statusMessage = 'Pairing failed');
    }
  }

  Future<void> _handleQrConnect() async {
    await showQrConnectDialog(context);
  }

  Future<void> _handleAdbConnectDirect(String host) async {
    setState(() => _statusMessage = 'Connecting to $host…');

    final result = await _di.adbService.connectDevice(host);

    if (result.success) {
      showSuccessDialog(
        context: context,
        title: 'Connected',
        message: result.message,
      );
      await _refreshDevices();
    } else {
      showErrorDialog(
        context,
        title: 'Connection Failed',
        message: result.message,
      );
      setState(() => _statusMessage = 'Connection failed');
    }
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
