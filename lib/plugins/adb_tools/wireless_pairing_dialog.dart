import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/show_overlay_dialog.dart';
import 'package:simutil/components/simutil_icons.dart';
import 'package:simutil/components/simutil_theme.dart';
import 'package:simutil/services/wifi_discovery_service.dart';

enum _Phase { scanning, enterManual }

const _spinnerFrames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
const _requiredPairingCodeLength = 6;

/// The result returned by [showWirelessConnectDialog].
///
/// When [pairingCode] is non-null the caller must run `adb pair host code`
/// before `adb connect host`. When null, run `adb connect host` directly.
class WirelessConnectRequest {
  const WirelessConnectRequest({required this.host, this.pairingCode});

  final String host;
  final String? pairingCode;
}

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
  _Phase _phase = _Phase.scanning;
  final List<WifiPairingDevice> _devices = [];
  int _selectedIndex = 0;
  int _spinnerIndex = 0;
  bool _hasError = false;

  late final TextEditingController _hostController;
  late final TextEditingController _codeController;

  // In enterManual phase: 0 = IP:Port field, 1 = pairing code field.
  int _focusedField = 0;

  StreamSubscription<WifiPairingDevice>? _subscription;
  Timer? _spinnerTimer;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController();
    _codeController = TextEditingController();
    _startWatching();
    _startSpinner();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _spinnerTimer?.cancel();
    _hostController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startWatching() {
    _subscription = component.discoveryService
        .watchConnectableDevices()
        .listen(
          (device) {
            setState(() => _devices.add(device));
          },
          onError: (Object _) {
            setState(() => _hasError = true);
          },
        );
  }

  void _startSpinner() {
    _spinnerTimer = Timer.periodic(
      const Duration(milliseconds: 150),
      (_) {
        setState(() {
          _spinnerIndex = (_spinnerIndex + 1) % _spinnerFrames.length;
        });
      },
    );
  }

  // Total options in scanning phase: discovered devices + "Enter manually".
  int get _optionCount => _devices.length + 1;
  int get _manualIndex => _devices.length;

  void _confirmSelection(int index) {
    if (index >= _devices.length) {
      // "Enter manually" selected — switch to manual-entry phase.
      setState(() {
        _focusedField = 0;
        _phase = _Phase.enterManual;
      });
      return;
    }
    // Discovered device selected — connect directly, no pairing code needed.
    component.onSelect(
      WirelessConnectRequest(host: _devices[index].hostPort),
    );
  }

  void _trySubmitManual() {
    final host = _hostController.text.trim();
    if (host.isEmpty) return;

    final code = _codeController.text.trim();
    // Code must be absent or exactly 6 digits; reject partial codes silently.
    if (code.isNotEmpty && code.length != _requiredPairingCodeLength) return;

    component.onSelect(
      WirelessConnectRequest(
        host: host,
        pairingCode: code.isEmpty ? null : code,
      ),
    );
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.escape) {
      if (_phase == _Phase.enterManual) {
        setState(() {
          _hostController.clear();
          _codeController.clear();
          _focusedField = 0;
          _phase = _Phase.scanning;
        });
        return true;
      }
      component.onCancel();
      return true;
    }

    switch (_phase) {
      case _Phase.scanning:
        if (event.logicalKey == LogicalKey.arrowUp) {
          setState(() {
            _selectedIndex = (_selectedIndex - 1).clamp(0, _optionCount - 1);
          });
          return true;
        }
        if (event.logicalKey == LogicalKey.arrowDown) {
          setState(() {
            _selectedIndex = (_selectedIndex + 1).clamp(0, _optionCount - 1);
          });
          return true;
        }
        if (event.logicalKey == LogicalKey.enter) {
          _confirmSelection(_selectedIndex);
          return true;
        }
        return false;

      case _Phase.enterManual:
        if (event.logicalKey == LogicalKey.tab ||
            event.logicalKey == LogicalKey.arrowDown) {
          setState(() {
            _focusedField = (_focusedField + 1).clamp(0, 1);
          });
          return true;
        }
        if (event.logicalKey == LogicalKey.arrowUp) {
          setState(() {
            _focusedField = (_focusedField - 1).clamp(0, 1);
          });
          return true;
        }
        return false;
    }
  }

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;
    return Center(
      child: Container(
        margin: EdgeInsets.all(8),
        decoration: st.dialogPanel('Connect via Wi-Fi'),
        child: Padding(
          padding: EdgeInsets.all(1),
          child: Focusable(
            focused: true,
            onKeyEvent: _handleKeyEvent,
            child: switch (_phase) {
              _Phase.scanning => _buildScanning(st),
              _Phase.enterManual => _buildEnterManual(st),
            },
          ),
        ),
      ),
    );
  }

  Component _buildScanning(SimutilTheme st) {
    final spinner = _spinnerFrames[_spinnerIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _hasError
              ? ' Scan unavailable.'
              : _devices.isEmpty
              ? ' $spinner Waiting for devices…'
              : ' $spinner Found ${_devices.length} device(s) — scanning…',
          style: _hasError ? st.errorStyle : st.label,
        ),
        Divider(),
        if (_devices.isEmpty && !_hasError)
          Text(
            '  Enable "Wireless debugging" on your Android device.',
            style: st.dimmed,
          ),
        ..._devices.asMap().entries.map((entry) {
          final isSelected = _selectedIndex == entry.key;
          final device = entry.value;
          return Row(
            children: [
              Text(
                isSelected ? ' ${SimutilIcons.pointer} ' : '   ',
                style: st.label,
              ),
              Text(
                '${device.name}  ${device.hostPort}',
                style: isSelected ? st.selected : st.body,
              ),
            ],
          );
        }),
        Row(
          children: [
            Text(
              _selectedIndex == _manualIndex
                  ? ' ${SimutilIcons.pointer} '
                  : '   ',
              style: st.label,
            ),
            Text(
              'Enter IP:Port manually',
              style:
                  _selectedIndex == _manualIndex ? st.selected : st.body,
            ),
          ],
        ),
        Divider(),
        Text(
          ' Navigate: <↑/↓> | Connect: <enter> | Cancel: <esc>',
          style: st.dimmed,
        ),
      ],
    );
  }

  Component _buildEnterManual(SimutilTheme st) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildInputField(
          st,
          0,
          'IP:Port',
          _hostController,
          '192.168.1.100:5555',
        ),
        SizedBox(height: 1),
        _buildInputField(
          st,
          1,
          'Pairing Code (optional, 6 digits)',
          _codeController,
          '123456',
        ),
        Divider(),
        Text(
          ' Switch: <tab> | Connect: <enter> | Back: <esc>',
          style: st.dimmed,
        ),
      ],
    );
  }

  Component _buildInputField(
    SimutilTheme st,
    int fieldIndex,
    String label,
    TextEditingController controller,
    String placeholder,
  ) {
    final isFocused = _focusedField == fieldIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(' $label:', style: isFocused ? st.label : st.body),
        Row(
          children: [
            Text('  ', style: st.body),
            Expanded(
              child: TextField(
                controller: controller,
                focused: isFocused,
                placeholder: placeholder,
                placeholderStyle: st.dimmed,
                style: st.body,
                onSubmitted: (_) => _trySubmitManual(),
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
}) =>
    showOverlayDialog<WirelessConnectRequest?>(
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
