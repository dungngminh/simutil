import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/simutil_theme.dart';

/// Result of wireless pairing dialog.
class WirelessPairingInput {
  final String host;
  final String pairingCode;

  const WirelessPairingInput({
    required this.host,
    required this.pairingCode,
  });
}

/// A modal dialog for wireless debugging pairing (Android 11+).
///
/// Use [showWirelessPairingDialog] to display this as an overlay.
class WirelessPairingDialog extends StatefulComponent {
  final void Function(WirelessPairingInput input) onSubmit;
  final VoidCallback onCancel;

  const WirelessPairingDialog({
    super.key,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<WirelessPairingDialog> createState() => _WirelessPairingDialogState();
}

class _WirelessPairingDialogState extends State<WirelessPairingDialog> {
  late TextEditingController _hostController;
  late TextEditingController _pairingCodeController;
  int _focusedField = 0; // 0 = host, 1 = pairing code

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController();
    _pairingCodeController = TextEditingController();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _pairingCodeController.dispose();
    super.dispose();
  }

  void _switchField(int direction) {
    setState(() {
      _focusedField = (_focusedField + direction).clamp(0, 1);
    });
  }

  void _trySubmit() {
    final host = _hostController.text.trim();
    final pairingCode = _pairingCodeController.text.trim();

    // Validate: host not empty, pairing code is exactly 6 digits
    if (host.isNotEmpty && pairingCode.length == 6) {
      component.onSubmit(
        WirelessPairingInput(host: host, pairingCode: pairingCode),
      );
    }
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    // Escape → cancel
    if (event.logicalKey == LogicalKey.escape) {
      component.onCancel();
      return true;
    }

    // Tab → switch field
    if (event.logicalKey == LogicalKey.tab) {
      _switchField(1);
      return true;
    }

    // Arrow up → previous field
    if (event.logicalKey == LogicalKey.arrowUp) {
      _switchField(-1);
      return true;
    }

    // Arrow down → next field
    if (event.logicalKey == LogicalKey.arrowDown) {
      _switchField(1);
      return true;
    }

    return false;
  }

  @override
  Component build(BuildContext context) {
    final st = SimutilTheme.of(context);

    return Center(
      child: Container(
        margin: EdgeInsets.all(8),
        decoration: st.dialogPanel('Wireless Debugging Pairing'),
        child: Padding(
          padding: EdgeInsets.all(1),
          child: Focusable(
            focused: true,
            onKeyEvent: _handleKeyEvent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(' Steps to pair:', style: st.label),
                Text(
                  '  1. On your Android device, go to Developer Options',
                  style: st.dimmed,
                ),
                Text('  2. Enable "Wireless debugging"', style: st.dimmed),
                Text(
                  '  3. Tap "Pair device with pairing code"',
                  style: st.dimmed,
                ),
                Text(
                  '  4. Enter the IP:Port and 6-digit pairing code below',
                  style: st.dimmed,
                ),
                Divider(),
                _buildInputField(
                  st,
                  0,
                  'IP:Port',
                  _hostController,
                  '192.168.1.100:37123',
                ),
                SizedBox(height: 1),
                _buildInputField(
                  st,
                  1,
                  'Pairing Code (6 digits)',
                  _pairingCodeController,
                  '123456',
                ),
                Divider(),
                Text(
                  ' Switch field: <tab> | Pair: <enter> | Cancel: <esc>',
                  style: st.dimmed,
                ),
              ],
            ),
          ),
        ),
      ),
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
                onSubmitted: (_) => _trySubmit(),
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

/// Show the wireless pairing dialog as a modal overlay.
///
/// Returns [WirelessPairingInput] if submitted, or `null` if cancelled.
Future<WirelessPairingInput?> showWirelessPairingDialog({
  required BuildContext context,
}) {
  final completer = Completer<WirelessPairingInput?>();
  OverlayEntry? entry;

  entry = OverlayEntry(
    opaque: false,
    builder: (context) {
      return WirelessPairingDialog(
        onSubmit: (input) {
          completer.complete(input);
          entry?.remove();
        },
        onCancel: () {
          completer.complete(null);
          entry?.remove();
        },
      );
    },
  );

  Overlay.of(context).insert(entry);

  return completer.future;
}
