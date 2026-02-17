import 'dart:async';
import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/app_header.dart';
import 'package:simutil/components/app_status_bar.dart';
import 'package:simutil/components/device_detail_panel.dart';
import 'package:simutil/components/device_list_component.dart';
import 'package:simutil/components/simutil_theme.dart';
import 'package:simutil/models/app_settings.dart';
import 'package:simutil/models/device.dart';
import 'package:simutil/models/device_type.dart';
import 'package:simutil/services/service_locator.dart';

/// Root component of the SimUtil TUI application.
///
/// Wraps the app in [TuiTheme] and orchestrates the layout:
/// ```
class SimutilApp extends StatefulComponent {
  const SimutilApp({super.key});

  @override
  State<SimutilApp> createState() => _SimutilAppState();
}

class _SimutilAppState extends State<SimutilApp> {
  // ── DI ────────────────────────────────────────────────────────
  final _di = ServiceLocator.instance;

  // ── State ─────────────────────────────────────────────────────
  AppSettings _settings = const AppSettings();
  TuiThemeData _themeData = TuiThemeData.dark;

  List<Device> _androidDevices = [];
  List<Device> _iosDevices = [];
  bool _loadingAndroid = true;
  bool _loadingIos = true;
  bool _isRefreshing = false;
  String _statusMessage = 'Loading devices…';

  int _androidSelectedIndex = 0;
  int _iosSelectedIndex = 0;

  /// Active panel: 'android' | 'ios'
  String _focusKey = 'android';

  /// Timer to refresh devices
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _refreshDevices();
    _initRefreshTimer();
  }

  void _initRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshDevices(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await _di.settingsService.load();
    setState(() {
      _settings = settings;
      _themeData = SimutilTheme.resolveTheme(settings.themeName);
    });
  }

  Future<void> _refreshDevices({bool silent = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    if (!silent) {
      setState(() {
        _loadingAndroid = true;
        _loadingIos = true;
        _statusMessage = 'Refreshing devices…';
      });
    }

    try {
      final results = await Future.wait([
        _di.adbService.listDevices().catchError((_) => <Device>[]),
        _di.simctlService.listDevices().catchError((_) => <Device>[]),
      ]);

      setState(() {
        _androidDevices = results[0];
        _iosDevices = results[1];
        _loadingAndroid = false;
        _loadingIos = false;
        _androidSelectedIndex = _androidSelectedIndex.clamp(
          0,
          (_androidDevices.length - 1).clamp(0, 999),
        );
        _iosSelectedIndex = _iosSelectedIndex.clamp(
          0,
          (_iosDevices.length - 1).clamp(0, 999),
        );
        final total = _androidDevices.length + _iosDevices.length;
        _statusMessage =
            '$total device(s) found  •  R Refresh  S Settings  Tab Switch  Q Quit';
      });
    } finally {
      _isRefreshing = false;
    }
  }

  // ── Build ─────────────────────────────────────────────────────

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
                // Left: Android + iOS
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: _androidPanel()),
                      Expanded(child: _iosPanel()),
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

  // ── Panels ──────────────────────────────────────────────────

  Component _androidPanel() {
    final focused = _focusKey == 'android';
    final st = context.simutilTheme;
    return Container(
      decoration: focused
          ? st.focusedPanel('Android Emulators')
          : st.unfocusedPanel('Android Emulators'),
      child: DeviceListComponent(
        devices: _androidDevices,
        focused: focused,
        isLoading: _loadingAndroid,
        selectedIndex: _androidSelectedIndex,
        emptyMessage: 'No Android emulators found',
        onSelectionChanged: (i) => setState(() => _androidSelectedIndex = i),
        onDeviceLaunch: _onDeviceLaunch,
      ),
    );
  }

  Component _iosPanel() {
    final st = context.simutilTheme;
    final focused = _focusKey == 'ios';
    return Container(
      decoration: focused
          ? st.focusedPanel('iOS Simulators')
          : st.unfocusedPanel('iOS Simulators'),
      child: DeviceListComponent(
        devices: _iosDevices,
        focused: focused,
        isLoading: _loadingIos,
        selectedIndex: _iosSelectedIndex,
        emptyMessage: 'No iOS simulators found',
        onSelectionChanged: (i) => setState(() => _iosSelectedIndex = i),
        onDeviceLaunch: _onDeviceLaunch,
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────

  Device? get _currentSelectedDevice {
    if (_focusKey == 'android' && _androidDevices.isNotEmpty) {
      return _androidDevices[_androidSelectedIndex];
    }
    if (_focusKey == 'ios' && _iosDevices.isNotEmpty) {
      return _iosDevices[_iosSelectedIndex];
    }
    return null;
  }

  // ── Key handling ────────────────────────────────────────────

  bool _handleGlobalKey(KeyboardEvent event) {
    switch (event.logicalKey) {
      case LogicalKey.tab || LogicalKey.arrowLeft || LogicalKey.arrowRight:
        setState(() {
          _androidSelectedIndex = 0;
          _iosSelectedIndex = 0;
          _focusKey = switch (_focusKey) {
            'android' => 'ios',
            _ => 'android',
          };
        });
        return true;
      case LogicalKey.keyR:
        _refreshDevices();
        return true;
      case LogicalKey.keyS:
        return true;
      case LogicalKey.keyQ:
        exit(0);
      default:
        return false;
    }
  }

  // ── Launch ──────────────────────────────────────────────────

  Future<void> _onDeviceLaunch(Device device) async {
    try {
      setState(() => _statusMessage = 'Launching ${device.name}…');
      if (device.type == DeviceType.android) {
        await _di.adbService.launchDevice(
          device.id,
          _settings.defaultLaunchOptions,
        );
      } else {
        await _di.simctlService.launchDevice(
          device.id,
          _settings.defaultLaunchOptions,
        );
      }
      _statusMessage = '${device.name} launched!';
      Future.delayed(Duration(seconds: 2), () => _refreshDevices(silent: true));
    } catch (e) {
      setState(() => _statusMessage = 'Failed to launch ${device.name}: $e');
    }
  }
}
