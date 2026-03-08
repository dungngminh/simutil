import 'dart:async';

import 'package:ascii_qr/ascii_qr.dart';
import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/simutil_theme.dart';

class QrConnectDialog extends StatefulComponent {
  const QrConnectDialog({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<QrConnectDialog> createState() => _QrConnectDialogState();
}

class _QrConnectDialogState extends State<QrConnectDialog> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Component build(BuildContext context) {
    final st = SimutilTheme.of(context);
    return Center(
      child: Container(
        width: 100,
        margin: EdgeInsets.all(4),
        decoration: st.dialogPanel('QR Code Pairing'),
        child: Padding(
          padding: EdgeInsets.all(1),
          child: Focusable(
            focused: true,
            onKeyEvent: (event) {
              if (event.logicalKey == LogicalKey.escape ||
                  event.logicalKey == LogicalKey.enter) {
                component.onClose();
                return true;
              }
              return false;
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildQrArt(),
                Divider(),
                Text(' Close: <enter> or <esc>', style: st.dimmed),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Component _buildQrArt() {
    final data = 'WIFI:T:ADB;S:simutil;P:123456;;';
    return Text(AsciiQrGenerator.generate(data));
  }
}

Future<void> showQrConnectDialog({required BuildContext context}) {
  final completer = Completer<void>();
  OverlayEntry? entry;

  entry = OverlayEntry(
    opaque: false,
    builder: (context) {
      return QrConnectDialog(
        onClose: () {
          completer.complete();
          entry?.remove();
        },
      );
    },
  );

  Overlay.of(context).insert(entry);

  return completer.future;
}
