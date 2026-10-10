import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_app/src/di.dart';
import 'package:simutil_app/src/ui/connect/connect_status.dart';
import 'package:simutil_app/src/ui/connect/qr_view.dart';
import 'package:simutil_app/src/ui/design/design.dart';

/// QR pairing: shows a fresh code and waits for the phone to scan it.
class QrTab extends StatefulWidget {
  const QrTab({super.key, required this.onConnected});

  final ValueChanged<String> onConnected;

  @override
  State<QrTab> createState() => _QrTabState();
}

class _QrTabState extends State<QrTab> {
  late QrPairingSession _session;
  String? _busy;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _session = getIt<AdbWirelessPairing>().startQr();
    _busy = 'Waiting for the phone to scan…';
    _error = null;
    final session = _session;
    session
        .result(
          onFound: () {
            if (mounted && identical(session, _session)) {
              setState(() => _busy = 'Pairing…');
            }
          },
        )
        .then((result) {
          if (!mounted || !identical(session, _session)) return;
          if (result.success) return widget.onConnected(result.message);
          setState(() {
            _busy = null;
            _error = result.message;
          });
        });
  }

  @override
  void dispose() {
    _session.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PhoneHint(
          'On the phone: Developer options › Wireless debugging › Pair '
          'device with QR code, then scan this code. Phone and computer must '
          'share the Wi-Fi network.',
        ),
        const SizedBox(height: 16),
        Center(
          child: AnimatedOpacity(
            duration: SimuTokens.motion,
            opacity: _error == null ? 1 : 0.35,
            child: QrView(data: _session.payload),
          ),
        ),
        const SizedBox(height: 16),
        ConnectStatus(busy: _busy, error: _error),
        if (_error != null) ...[
          const SizedBox(height: 10),
          SimuButton(
            label: 'Try again',
            icon: LucideIcons.refreshCw,
            onPressed: () {
              _session.cancel();
              setState(_start);
            },
          ),
        ],
        const SizedBox(height: 4),
        Text(
          'Needs Android 11 or newer.',
          style: t.caption.copyWith(color: t.textFaint),
        ),
      ],
    );
  }
}
