import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/loading_state.dart';
import 'package:simutil/components/pin_code_fields.dart';
import 'package:simutil/components/show_overlay_dialog.dart';
import 'package:simutil/components/simutil_icons.dart';
import 'package:simutil/components/simutil_theme.dart';
import 'package:simutil/models/wifi_pairing_device.dart';
import 'package:simutil/models/wireless_connect_request.dart';
import 'package:simutil/services/wifi_discovery_service.dart';

const _requiredPinCodeLength = 6;
final _pinCodeRegex = RegExp(r'^\d{6}$');
const _enterCodeRoute = '/enter-code';
const _manualRoute = '/manual';

class WirelessConnectDialog extends StatefulComponent {
  const WirelessConnectDialog({
    super.key,
    required this.discoveryService,
    required this.onSelect,
    required this.onCancel,
  });

  final WifiDiscoveryService discoveryService;
  final void Function(WirelessConnectRequest request) onSelect;
  final VoidCallback onCancel;

  @override
  State<WirelessConnectDialog> createState() => _WirelessConnectDialogState();
}

class _WirelessConnectDialogState extends State<WirelessConnectDialog> {
  final List<WifiPairingDevice> _pairingDevices = [];
  WifiPairingDevice? _selectedPairingDevice;
  int _selectedIndex = 0;
  bool _hasError = false;

  StreamSubscription<WifiPairingDevice>? _subscription;

  @override
  void initState() {
    super.initState();
    _startWatching();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _startWatching() {
    _subscription = component.discoveryService.watchPairingDevices().listen(
      (device) {
        setState(() => _pairingDevices.add(device));
      },
      onError: (_) {
        setState(() => _hasError = true);
      },
    );
  }

  int get _deviceCount => _pairingDevices.length;

  void _openEnterCode(BuildContext navContext, int index) {
    if (index < 0 || index >= _pairingDevices.length) return;
    final selectedDevice = _pairingDevices[index];
    _goToEnterCode(selectedDevice);
    Navigator.of(navContext).pushNamed(_enterCodeRoute);
  }

  void _openManualEntry(BuildContext navContext) {
    _goToManual();
    Navigator.of(navContext).pushNamed(_manualRoute);
  }

  void _resetToScanState() {
    setState(() => _selectedPairingDevice = null);
  }

  void _goToManual() {
    setState(() => _selectedPairingDevice = null);
  }

  void _goToEnterCode(WifiPairingDevice device) {
    setState(() => _selectedPairingDevice = device);
  }

  void _submitWithCode(String code) {
    final host = _selectedPairingDevice?.hostPort ?? '';
    if (host.isEmpty || !_pinCodeRegex.hasMatch(code)) return;
    component.onSelect(WirelessConnectRequest(host: host, pairingCode: code));
  }

  void _trySubmitManual(String host, String? pairingCode) {
    component.onSelect(
      WirelessConnectRequest(host: host, pairingCode: pairingCode),
    );
  }

  bool _handleScanningKeyEvent(KeyboardEvent event, BuildContext navContext) {
    if (event.logicalKey == LogicalKey.escape) {
      component.onCancel();
      return true;
    }
    if (_deviceCount == 0) {
      if (event.logicalKey == LogicalKey.keyM) {
        _openManualEntry(navContext);
        return true;
      }
      return false;
    }

    if (event.logicalKey == LogicalKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1).clamp(0, _deviceCount - 1);
      });
      return true;
    }
    if (event.logicalKey == LogicalKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(0, _deviceCount - 1);
      });
      return true;
    }
    if (event.logicalKey == LogicalKey.enter) {
      _openEnterCode(navContext, _selectedIndex);
      return true;
    }
    if (event.logicalKey == LogicalKey.keyM) {
      _openManualEntry(navContext);
      return true;
    }
    return false;
  }

  bool _handleEnterCodeKeyEvent(KeyboardEvent event, BuildContext navContext) {
    if (event.logicalKey == LogicalKey.escape) {
      _resetToScanState();
      Navigator.of(navContext).pop();
      return true;
    }
    return false;
  }

  bool _handleManualKeyEvent(KeyboardEvent event, BuildContext navContext) {
    if (event.logicalKey == LogicalKey.escape) {
      _resetToScanState();
      Navigator.of(navContext).pop();
      return true;
    }
    return false;
  }

  @override
  Component build(BuildContext context) {
    return Navigator(
      home: Builder(
        builder: (navContext) => Focusable(
          focused: true,
          onKeyEvent: (event) => _handleScanningKeyEvent(event, navContext),
          child: _ScanningPhaseView(
            devices: _pairingDevices,
            selectedIndex: _selectedIndex,
            hasError: _hasError,
          ),
        ),
      ),
      routes: {
        _enterCodeRoute: (navContext) => Focusable(
          focused: true,
          onKeyEvent: (event) => _handleEnterCodeKeyEvent(event, navContext),
          child: _EnterCodePhaseView(
            selectedDevice: _selectedPairingDevice,
            hostPort: _selectedPairingDevice?.hostPort ?? '',
            onSubmitted: _submitWithCode,
          ),
        ),
        _manualRoute: (navContext) => Focusable(
          focused: true,
          onKeyEvent: (event) => _handleManualKeyEvent(event, navContext),
          child: _EnterManualPhaseView(onSubmitted: _trySubmitManual),
        ),
      },
      popBehavior: const PopBehavior(escapeEnabled: false),
    );
  }
}

class _ScanningPhaseView extends StatelessComponent {
  const _ScanningPhaseView({
    required this.devices,
    required this.selectedIndex,
    required this.hasError,
  });

  final List<WifiPairingDevice> devices;
  final int selectedIndex;
  final bool hasError;

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;
    return Center(
      child: Container(
        margin: EdgeInsets.all(6),
        padding: EdgeInsets.all(1),
        width: 100,
        height: 30,
        decoration: st.dialogPanel('Pair using Pairing Code'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AvailableDevicesPanel(
              devices: devices,
              selectedIndex: selectedIndex,
              hasError: hasError,
            ),
            Divider(),
            Text(
              devices.isEmpty
                  ? ' Manual connection: <m> | Close: <esc>'
                  : ' Navigate: <↑/↓> | Pair: <enter> | Manual: <m> | Close: <esc>',
              style: st.dimmed,
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailableDevicesPanel extends StatelessComponent {
  const _AvailableDevicesPanel({
    required this.devices,
    required this.selectedIndex,
    required this.hasError,
  });

  final List<WifiPairingDevice> devices;
  final int selectedIndex;
  final bool hasError;

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;
    return Expanded(
      child: switch ((hasError, devices.isEmpty)) {
        (true, _) => Center(
          child: Text('Device discovery is unavailable.', style: st.errorStyle),
        ),
        (false, true) => _SearchingState(),
        (false, false) => _DiscoveredDeviceList(
          devices: devices,
          selectedIndex: selectedIndex,
        ),
      },
    );
  }
}

class _SearchingState extends StatelessComponent {
  const _SearchingState();

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: LoadingState(
              message: 'Searching for devices...',
              style: st.dimmed,
            ),
          ),
        ),
        Text(
          'Set your Android 11+ device to pairing mode',
          style: st.bold,
          textAlign: TextAlign.center,
        ),
        Text(
          'Go to Developer options > Wireless debugging > Pair device with pairing code',
          style: st.dimmed,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _DiscoveredDeviceList extends StatelessComponent {
  const _DiscoveredDeviceList({
    required this.devices,
    required this.selectedIndex,
  });

  final List<WifiPairingDevice> devices;
  final int selectedIndex;

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Found ${devices.length} device(s)', style: st.dimmed),
            SizedBox(width: 1),
            LoadingState(style: st.dimmed),
          ],
        ),
        Divider(),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: devices.asMap().entries.map((entry) {
              final isSelected = selectedIndex == entry.key;
              final device = entry.value;
              return Row(
                children: [
                  Text(
                    isSelected ? ' ${SimutilIcons.pointer} ' : '   ',
                    style: st.label,
                  ),
                  Text(
                    'Device at ${device.hostPort}',
                    style: isSelected ? st.selected : st.body,
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _EnterCodePhaseView extends StatefulComponent {
  const _EnterCodePhaseView({
    required this.selectedDevice,
    required this.hostPort,
    required this.onSubmitted,
  });

  final WifiPairingDevice? selectedDevice;
  final String hostPort;
  final void Function(String code) onSubmitted;

  @override
  State<_EnterCodePhaseView> createState() => _EnterCodePhaseViewState();
}

class _EnterCodePhaseViewState extends State<_EnterCodePhaseView> {
  late final List<TextEditingController> _pinControllers;
  int _focusedPinIndex = 0;

  @override
  void initState() {
    super.initState();
    _pinControllers = List.generate(
      _requiredPinCodeLength,
      (_) => TextEditingController(),
    );
  }

  @override
  void dispose() {
    for (final c in _pinControllers) {
      c.dispose();
    }
    super.dispose();
  }

  String get _currentPinCode => _pinControllers.map((c) => c.text).join();

  void _handlePinChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      setState(() => _pinControllers[index].clear());
      return;
    }
    if (digits.length == 1) {
      setState(() {
        _pinControllers[index].text = digits;
        if (index < _requiredPinCodeLength - 1) _focusedPinIndex = index + 1;
      });
      return;
    }
    // Paste support: distribute digits from current slot forward.
    setState(() {
      var cursor = index;
      for (final digit in digits.split('')) {
        if (cursor >= _requiredPinCodeLength) break;
        _pinControllers[cursor].text = digit;
        cursor++;
      }
      _focusedPinIndex = cursor >= _requiredPinCodeLength
          ? _requiredPinCodeLength - 1
          : cursor;
    });
  }

  bool _handlePinKeyEvent(int index, KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.arrowLeft) {
      setState(
        () =>
            _focusedPinIndex = (index - 1).clamp(0, _requiredPinCodeLength - 1),
      );
      return true;
    }
    if (event.logicalKey == LogicalKey.arrowRight ||
        event.logicalKey == LogicalKey.tab) {
      setState(
        () =>
            _focusedPinIndex = (index + 1).clamp(0, _requiredPinCodeLength - 1),
      );
      return true;
    }
    if (event.logicalKey == LogicalKey.backspace &&
        _pinControllers[index].text.isEmpty) {
      setState(() {
        final prev = (index - 1).clamp(0, _requiredPinCodeLength - 1);
        _pinControllers[prev].clear();
        _focusedPinIndex = prev;
      });
      return true;
    }
    if (event.logicalKey == LogicalKey.enter) {
      final code = _currentPinCode;
      if (_pinCodeRegex.hasMatch(code)) component.onSubmitted(code);
      return true;
    }
    return false;
  }

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;
    return Center(
      child: Container(
        width: 50,
        decoration: context.simutilTheme.dialogPanel(
          'Pairing with ${component.hostPort}',
        ),
        child: Padding(
          padding: EdgeInsets.all(1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PinCodeFields(
                label: 'Pairing Code (6 digits)',
                groupFocused: true,
                pinControllers: _pinControllers,
                focusedPinIndex: _focusedPinIndex,
                onPinChanged: _handlePinChanged,
                onPinKeyEvent: _handlePinKeyEvent,
                onSubmitted: () {
                  final code = _currentPinCode;
                  if (_pinCodeRegex.hasMatch(code)) component.onSubmitted(code);
                },
              ),
              Divider(),
              Text(' Pair: <enter> | Back: <esc>', style: st.dimmed),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnterManualPhaseView extends StatefulComponent {
  const _EnterManualPhaseView({required this.onSubmitted});

  final void Function(String host, String? pairingCode) onSubmitted;

  @override
  State<_EnterManualPhaseView> createState() => _EnterManualPhaseViewState();
}

class _EnterManualPhaseViewState extends State<_EnterManualPhaseView> {
  late final TextEditingController _hostController;
  late final List<TextEditingController> _pinControllers;

  // 0 = IP:Port field, 1 = PIN code field.
  int _focusedField = 0;
  int _focusedPinIndex = 0;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController();
    _pinControllers = List.generate(
      _requiredPinCodeLength,
      (_) => TextEditingController(),
    );
  }

  @override
  void dispose() {
    _hostController.dispose();
    for (final c in _pinControllers) {
      c.dispose();
    }
    super.dispose();
  }

  String get _currentPinCode => _pinControllers.map((c) => c.text).join();

  void _trySubmit() {
    final host = _hostController.text.trim();
    if (host.isEmpty) return;
    final code = _currentPinCode;
    final hasAnyPinDigit = _pinControllers.any((c) => c.text.isNotEmpty);
    if (hasAnyPinDigit && !_pinCodeRegex.hasMatch(code)) return;
    component.onSubmitted(host, hasAnyPinDigit ? code : null);
  }

  void _handlePinChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      setState(() => _pinControllers[index].clear());
      return;
    }
    if (digits.length == 1) {
      setState(() {
        _pinControllers[index].text = digits;
        if (index < _requiredPinCodeLength - 1) _focusedPinIndex = index + 1;
      });
      return;
    }
    setState(() {
      var cursor = index;
      for (final digit in digits.split('')) {
        if (cursor >= _requiredPinCodeLength) break;
        _pinControllers[cursor].text = digit;
        cursor++;
      }
      _focusedPinIndex = cursor >= _requiredPinCodeLength
          ? _requiredPinCodeLength - 1
          : cursor;
    });
  }

  bool _handlePinKeyEvent(int index, KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.arrowLeft) {
      setState(
        () =>
            _focusedPinIndex = (index - 1).clamp(0, _requiredPinCodeLength - 1),
      );
      return true;
    }
    if (event.logicalKey == LogicalKey.arrowRight ||
        event.logicalKey == LogicalKey.tab) {
      setState(
        () =>
            _focusedPinIndex = (index + 1).clamp(0, _requiredPinCodeLength - 1),
      );
      return true;
    }
    if (event.logicalKey == LogicalKey.backspace &&
        _pinControllers[index].text.isEmpty) {
      setState(() {
        final prev = (index - 1).clamp(0, _requiredPinCodeLength - 1);
        _pinControllers[prev].clear();
        _focusedPinIndex = prev;
      });
      return true;
    }
    if (event.logicalKey == LogicalKey.enter) {
      _trySubmit();
      return true;
    }
    return false;
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.tab ||
        event.logicalKey == LogicalKey.arrowDown) {
      setState(() => _focusedField = (_focusedField + 1).clamp(0, 1));
      return true;
    }
    if (event.logicalKey == LogicalKey.arrowUp) {
      setState(() => _focusedField = (_focusedField - 1).clamp(0, 1));
      return true;
    }
    return false;
  }

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;
    return Focusable(
      focused: true,
      onKeyEvent: _handleKeyEvent,
      child: Center(
        child: Container(
          margin: EdgeInsets.all(6),
          padding: EdgeInsets.all(1),
          width: 100,
          decoration: st.dialogPanel('Pair using Pairing Code'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _LabeledInputField(
                label: 'IP:Port',
                controller: _hostController,
                placeholder: '192.168.1.100:5555',
                focused: _focusedField == 0,
                onSubmitted: _trySubmit,
              ),
              SizedBox(height: 1),
              PinCodeFields(
                label: 'Pairing Code (6 digits)',
                crossAxisAlignment: CrossAxisAlignment.start,
                groupFocused: _focusedField == 1,
                spacing: 0,
                pinControllers: _pinControllers,
                focusedPinIndex: _focusedPinIndex,
                onPinChanged: _handlePinChanged,
                onPinKeyEvent: _handlePinKeyEvent,
                onSubmitted: _trySubmit,
              ),
              Divider(),
              Text(
                ' Connect: <enter> | Switch field: <tab/↑/↓> | Back: <esc>',
                style: st.dimmed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledInputField extends StatelessComponent {
  const _LabeledInputField({
    required this.label,
    required this.controller,
    required this.placeholder,
    required this.focused,
    required this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String placeholder;
  final bool focused;
  final VoidCallback onSubmitted;

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(' $label:', style: focused ? st.label : st.body),
        Row(
          children: [
            Text('  ', style: st.body),
            Expanded(
              child: TextField(
                controller: controller,
                focused: focused,
                placeholder: placeholder,
                placeholderStyle: st.dimmed,
                style: st.body,
                onSubmitted: (_) => onSubmitted(),
                decoration: InputDecoration(
                  border: BoxBorder.all(
                    style: BoxBorderStyle.rounded,
                    color: st.outline,
                  ),
                  focusedBorder: BoxBorder.all(
                    style: BoxBorderStyle.rounded,
                    color: st.primary,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 1),
                ),
              ),
            ),
            Text('  ', style: st.body),
          ],
        ),
      ],
    );
  }
}

Future<WirelessConnectRequest?> showWirelessConnectDialog({
  required BuildContext context,
  required WifiDiscoveryService discoveryService,
}) => showOverlayDialog<WirelessConnectRequest?>(
  context: context,
  builder: (context, completer, entry) => WirelessConnectDialog(
    discoveryService: discoveryService,
    onSelect: (request) {
      completer.complete(request);
      entry?.remove();
    },
    onCancel: () {
      completer.complete(null);
      entry?.remove();
    },
  ),
);
