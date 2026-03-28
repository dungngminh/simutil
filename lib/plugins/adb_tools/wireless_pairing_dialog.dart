import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/show_overlay_dialog.dart';
import 'package:simutil/components/simutil_theme.dart';

class WirelessPairingInput {
  const WirelessPairingInput({required this.host, required this.pairingCode});
  final String host;
  final String pairingCode;
}

class WirelessPairingDialog extends StatefulComponent {
  const WirelessPairingDialog({
    super.key,
    required this.onSubmit,
    required this.onCancel,
  });
  final void Function(WirelessPairingInput input) onSubmit;
  final VoidCallback onCancel;

  @override
  State<WirelessPairingDialog> createState() => _WirelessPairingDialogState();
}

class _WirelessPairingDialogState extends State<WirelessPairingDialog> {
  late TextEditingController _hostController;
  late TextEditingController _pairingCodeController;
  int _focusedField = 0;

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

    if (host.isNotEmpty && pairingCode.length == 6) {
      component.onSubmit(
        WirelessPairingInput(host: host, pairingCode: pairingCode),
      );
    }
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.escape) {
      component.onCancel();
      return true;
    }

    if (event.logicalKey == LogicalKey.tab) {
      _switchField(1);
      return true;
    }

    if (event.logicalKey == LogicalKey.arrowUp) {
      _switchField(-1);
      return true;
    }

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
                  style: st.dialogHint,
                ),
                Text('  2. Enable "Wireless debugging"', style: st.dialogHint),
                Text(
                  '  3. Tap "Pair device with pairing code"',
                  style: st.dialogHint,
                ),
                Text(
                  '  4. Enter the IP:Port and 6-digit pairing code below',
                  style: st.dialogHint,
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
                  style: st.dialogHint,
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
        Text(' $label:', style: isFocused ? st.label : st.dialogBody),
        Row(
          children: [
            Text('  ', style: st.body),
            Expanded(
              child: TextField(
                controller: controller,
                focused: isFocused,
                placeholder: placeholder,
                placeholderStyle: st.dialogHint,
                style: st.dialogBody,
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

Future<WirelessPairingInput?> showWirelessPairingDialog({
  required BuildContext context,
}) => showOverlayDialog<WirelessPairingInput?>(
  context: context,
  builder: (context, completer, entry) => WirelessPairingDialog(
    onSubmit: (input) {
      completer.complete(input);
      entry?.remove();
    },
    onCancel: () {
      completer.complete(null);
      entry?.remove();
    },
  ),
);
