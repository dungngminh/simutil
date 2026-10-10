import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_app/src/ui/connect/ip_tab.dart';
import 'package:simutil_app/src/ui/connect/pairing_code_tab.dart';
import 'package:simutil_app/src/ui/connect/qr_tab.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_app/src/ui/recording_toast.dart';

/// Connects an Android device over Wi-Fi: QR code, pairing code or IP.
Future<void> showConnectDeviceDialog(BuildContext context) {
  final devices = context.read<DevicesCubit>();
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => ConnectDeviceDialog(
      onConnected: (message) {
        Navigator.of(dialogContext).pop();
        showNotice(
          context,
          'Device connected',
          subtitle: message,
          tone: NoticeTone.success,
        );
        devices.refresh(silent: true);
      },
    ),
  );
}

enum _Method {
  qr('QR code', LucideIcons.qrCode),
  code('Pairing code', LucideIcons.hash),
  ip('IP address', LucideIcons.globe);

  const _Method(this.label, this.icon);

  final String label;
  final IconData icon;
}

class ConnectDeviceDialog extends StatefulWidget {
  const ConnectDeviceDialog({super.key, required this.onConnected});

  final ValueChanged<String> onConnected;

  @override
  State<ConnectDeviceDialog> createState() => _ConnectDeviceDialogState();
}

class _ConnectDeviceDialogState extends State<ConnectDeviceDialog> {
  var _method = _Method.qr;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Dialog(
      backgroundColor: t.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SimuTokens.radiusLarge),
        side: BorderSide(color: t.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(onClose: () => Navigator.of(context).pop()),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final method in _Method.values)
                    SimuButton(
                      label: method.label,
                      icon: method.icon,
                      primary: method == _method,
                      onPressed: () => setState(() => _method = method),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              switch (_method) {
                _Method.qr => QrTab(onConnected: widget.onConnected),
                _Method.code => PairingCodeTab(onConnected: widget.onConnected),
                _Method.ip => IpTab(onConnected: widget.onConnected),
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          'Connect a device over Wi-Fi',
          style: SimuTokens.of(context).title,
        ),
      ),
      SimuIconButton(icon: LucideIcons.x, tooltip: 'Close', onPressed: onClose),
    ],
  );
}
