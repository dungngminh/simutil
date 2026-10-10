import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_app/src/di.dart';
import 'package:simutil_app/src/ui/connect/connect_status.dart';
import 'package:simutil_app/src/ui/design/design.dart';

/// Pairing with the six-digit code: phones advertising a pairing endpoint
/// over mDNS, or a host:port typed by hand.
class PairingCodeTab extends StatefulWidget {
  const PairingCodeTab({super.key, required this.onConnected});

  final ValueChanged<String> onConnected;

  @override
  State<PairingCodeTab> createState() => _PairingCodeTabState();
}

class _PairingCodeTabState extends State<PairingCodeTab> {
  final _found = <WifiPairingDevice>[];
  StreamSubscription<WifiPairingDevice>? _discovery;
  WifiPairingDevice? _selected;
  var _manual = false;
  final _host = TextEditingController();
  final _code = TextEditingController();
  String? _busy;
  String? _error;

  static final _codePattern = RegExp(r'^\d{6}$');

  @override
  void initState() {
    super.initState();
    _discovery = getIt<WifiDiscoveryService>().watchPairingDevices().listen(
      (device) => setState(() => _found.add(device)),
    );
  }

  @override
  void dispose() {
    _discovery?.cancel();
    _host.dispose();
    _code.dispose();
    super.dispose();
  }

  String? get _target => _manual ? _host.text.trim() : _selected?.hostPort;

  Future<void> _pair() async {
    final target = _target;
    final code = _code.text.trim();
    if (target == null || !target.contains(':')) {
      return setState(() => _error = 'Enter the host:port shown on the phone');
    }
    if (!_codePattern.hasMatch(code)) {
      return setState(() => _error = 'The pairing code has 6 digits');
    }
    setState(() {
      _busy = 'Pairing with $target…';
      _error = null;
    });
    final result = await getIt<AdbWirelessPairing>().pairAndConnect(
      target,
      code,
    );
    if (!mounted) return;
    if (result.success) return widget.onConnected(result.message);
    setState(() {
      _busy = null;
      _error = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PhoneHint(
          'On the phone: Developer options › Wireless debugging › Pair '
          'device with pairing code. It shows up below; pick it and type the '
          'code.',
        ),
        const SizedBox(height: 14),
        if (_manual)
          SimuTextField(
            controller: _host,
            hint: 'IP address and port, e.g. 192.168.1.20:37123',
            icon: LucideIcons.globe,
            monospace: true,
            autofocus: true,
          )
        else
          _FoundList(
            devices: _found,
            selected: _selected,
            onSelect: (d) => setState(() => _selected = d),
          ),
        const SizedBox(height: 10),
        if (_manual || _selected != null)
          _CodeRow(controller: _code, onSubmit: _busy == null ? _pair : null),
        const SizedBox(height: 10),
        ConnectStatus(busy: _busy, error: _error),
        const SizedBox(height: 6),
        SimuButton(
          label: _manual ? 'Find phones on the network' : 'Enter manually',
          icon: _manual ? LucideIcons.radar : LucideIcons.keyboard,
          onPressed: () => setState(() {
            _manual = !_manual;
            _error = null;
          }),
        ),
      ],
    );
  }
}

/// Discovered pairing endpoints, or a scanning hint.
class _FoundList extends StatelessWidget {
  const _FoundList({
    required this.devices,
    required this.selected,
    required this.onSelect,
  });

  final List<WifiPairingDevice> devices;
  final WifiPairingDevice? selected;
  final ValueChanged<WifiPairingDevice> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    if (devices.isEmpty) {
      return const ConnectStatus(busy: 'Looking for phones in pairing mode…');
    }
    return Column(
      children: [
        for (final device in devices)
          SimuHoverable(
            onTap: () => onSelect(device),
            builder: (context, hovered) {
              final active = device.hostPort == selected?.hostPort;
              return AnimatedContainer(
                duration: SimuTokens.motion,
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? t.accent.withValues(alpha: 0.12)
                      : hovered
                      ? t.hover
                      : t.raised,
                  borderRadius: BorderRadius.circular(SimuTokens.radius),
                  border: Border.all(color: active ? t.accent : t.border),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.smartphone, size: 15, color: t.android),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        device.name.replaceAll('_', ' '),
                        style: t.label,
                      ),
                    ),
                    Text(device.hostPort, style: t.mono),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Six-digit code field and the Pair button.
class _CodeRow extends StatelessWidget {
  const _CodeRow({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: SimuTextField(
          controller: controller,
          hint: 'Pairing code',
          icon: LucideIcons.keyRound,
          monospace: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onSubmitted: (_) => onSubmit?.call(),
        ),
      ),
      const SizedBox(width: 8),
      SimuButton(label: 'Pair', primary: true, onPressed: onSubmit),
    ],
  );
}
