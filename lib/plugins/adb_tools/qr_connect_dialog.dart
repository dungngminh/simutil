import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/show_overlay_dialog.dart';
import 'package:simutil/components/simutil_theme.dart';

class QrConnectDialog extends StatelessComponent {
  const QrConnectDialog({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;
    return Center(
      child: Container(
        margin: EdgeInsets.all(8),
        decoration: st.dialogPanel('QR Code Pairing'),
        child: Padding(
          padding: EdgeInsets.all(1),
          child: Focusable(
            focused: true,
            onKeyEvent: (event) {
              if (event.logicalKey == LogicalKey.escape ||
                  event.logicalKey == LogicalKey.enter) {
                onClose();
                return true;
              }
              return false;
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(' QR Code pairing is not yet supported.', style: st.label),
                Divider(),
                Text(
                  '  True QR pairing requires this tool to act as an ADB\n'
                  '  pairing server (mDNS advertisement + TLS/SPAKE2), which\n'
                  '  is not implemented yet.',
                  style: st.dimmed,
                ),
                SizedBox(height: 1),
                Text(
                  '  Use "Connect via Wi-Fi" instead:',
                  style: st.body,
                ),
                Text(
                  '    1. On your Android device, go to Developer Options',
                  style: st.dimmed,
                ),
                Text('    2. Enable "Wireless debugging"', style: st.dimmed),
                Text(
                  '    3. Tap "Pair device with pairing code"',
                  style: st.dimmed,
                ),
                Text(
                  '    4. The device will be discovered automatically.',
                  style: st.dimmed,
                ),
                Divider(),
                Text(' Close: <enter> or <esc>', style: st.dimmed),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showQrConnectDialog(BuildContext context) =>
    showOverlayDialog<void>(
      context: context,
      builder: (context, completer, entry) => QrConnectDialog(
        onClose: () {
          completer.complete();
          entry?.remove();
        },
      ),
    );
