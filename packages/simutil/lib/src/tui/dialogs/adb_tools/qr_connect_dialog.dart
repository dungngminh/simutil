import 'dart:async';

import 'package:ascii_qr/ascii_qr.dart';
import 'package:nocterm/nocterm.dart';
import 'package:simutil/src/tui/components/show_overlay_dialog.dart';
import 'package:simutil/src/tui/components/simutil_theme.dart';
import 'package:simutil_adb/simutil_adb.dart';

/// Wireless ADB pairing with a QR code: shows a fresh code, waits for the
/// phone to scan it (Developer options › Wireless debugging › Pair device
/// with QR code), then pairs and connects.
class QrConnectDialog extends StatefulComponent {
  /// Creates the dialog; [onClose] gets the result, or null if dismissed.
  const QrConnectDialog({
    super.key,
    required this.pairing,
    required this.onClose,
  });

  /// Pairs and connects once the phone scanned the code.
  final AdbWirelessPairing pairing;

  /// Called when the dialog closes.
  final void Function(AdbConnectResult? result) onClose;

  @override
  State<QrConnectDialog> createState() => _QrConnectDialogState();
}

class _QrConnectDialogState extends State<QrConnectDialog> {
  late QrPairingSession _session;
  String _status = '';
  AdbConnectResult? _result;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    final session = _session = component.pairing.startQr();
    _status = 'Waiting for the phone to scan…';
    _result = null;
    session
        .result(
          onFound: () {
            if (identical(session, _session)) {
              setState(() => _status = 'Pairing…');
            }
          },
        )
        .then((result) {
          if (!identical(session, _session)) return;
          if (result.success) return component.onClose(result);
          setState(() => _result = result);
        });
  }

  void _close() {
    _session.cancel();
    component.onClose(null);
  }

  @override
  void dispose() {
    _session.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;
    final failed = _result;
    return Center(
      child: Container(
        width: 100,
        margin: EdgeInsets.all(4),
        decoration: st.dialogPanel('Pairing with QR Code'),
        child: Padding(
          padding: EdgeInsets.all(1),
          child: Focusable(
            focused: true,
            onKeyEvent: (event) {
              if (event.logicalKey == LogicalKey.escape ||
                  event.logicalKey == LogicalKey.enter) {
                _close();
                return true;
              }
              if (failed != null && event.logicalKey == LogicalKey.keyR) {
                _session.cancel();
                setState(_start);
                return true;
              }
              return false;
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Phone: Developer options › Wireless debugging › '
                  'Pair device with QR code',
                  style: st.dimmed,
                ),
                Text(AsciiQrGenerator.generate(_session.payload)),
                Divider(),
                if (failed == null)
                  Text(' $_status', style: TextStyle(color: st.warning))
                else
                  Text(
                    ' ${failed.message.trim()}',
                    style: TextStyle(color: st.error),
                  ),
                Text(
                  failed == null
                      ? ' Close: <enter> or <esc>'
                      : ' New code: <r>   Close: <enter> or <esc>',
                  style: st.dimmed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the QR pairing dialog; resolves with the connect result once the
/// phone paired, or null when dismissed.
Future<AdbConnectResult?> showQrConnectDialog(
  BuildContext context, {
  required AdbWirelessPairing pairing,
}) => showOverlayDialog<AdbConnectResult?>(
  context: context,
  builder: (context, completer, entry) => QrConnectDialog(
    pairing: pairing,
    onClose: (result) {
      if (!completer.isCompleted) completer.complete(result);
      entry?.remove();
    },
  ),
);
