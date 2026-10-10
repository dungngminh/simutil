import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_app/src/devices/devices_state.dart';
import 'package:simutil_app/src/di.dart';
import 'package:simutil_app/src/ui/connect/connect_status.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_core/simutil_core.dart';

/// `adb connect` to an address, or switch a USB-connected device to Wi-Fi.
class IpTab extends StatefulWidget {
  const IpTab({super.key, required this.onConnected});

  final ValueChanged<String> onConnected;

  @override
  State<IpTab> createState() => _IpTabState();
}

class _IpTabState extends State<IpTab> {
  final _host = TextEditingController();
  String? _busy;
  String? _error;

  static const _defaultPort = 5555;

  AndroidDeviceService get _adb => getIt<AndroidDeviceService>();

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  Future<void> _run(
    String busy,
    Future<AdbConnectResult> Function() job,
  ) async {
    setState(() {
      _busy = busy;
      _error = null;
    });
    final result = await job();
    if (!mounted) return;
    if (result.success) return widget.onConnected(result.message);
    setState(() {
      _busy = null;
      _error = result.message;
    });
  }

  void _connect() {
    final input = _host.text.trim();
    if (input.isEmpty) return setState(() => _error = 'Enter an IP address');
    final target = input.contains(':') ? input : '$input:$_defaultPort';
    _run('Connecting to $target…', () => _adb.connectDevice(target));
  }

  /// Reads the IP over USB first: `adb tcpip` restarts adbd and drops USB.
  void _switchToWifi(Device device) =>
      _run('Switching ${device.name} to Wi-Fi…', () async {
        final ip = await _adb.getDeviceIpAddress(device.id);
        if (ip == null) {
          return const AdbConnectResult(
            success: false,
            message: 'The device has no Wi-Fi address. Join a network first.',
          );
        }
        if (!await _adb.enableTcpIp(device.id, port: _defaultPort)) {
          return const AdbConnectResult(
            success: false,
            message: 'adb tcpip failed',
          );
        }
        await Future<void>.delayed(const Duration(seconds: 2));
        return _adb.connectDevice('$ip:$_defaultPort');
      });

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final usb = context
        .value<DevicesCubit, DevicesState>()
        .androidDevices
        .where((d) => !d.id.contains(':'))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PhoneHint(
          'For a device already paired, or one listening with adb tcpip. '
          'The port defaults to 5555.',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SimuTextField(
                controller: _host,
                hint: '192.168.1.20 or 192.168.1.20:5555',
                icon: LucideIcons.globe,
                monospace: true,
                autofocus: true,
                onSubmitted: (_) => _busy == null ? _connect() : null,
              ),
            ),
            const SizedBox(width: 8),
            SimuButton(
              label: 'Connect',
              primary: true,
              onPressed: _busy == null ? _connect : null,
            ),
          ],
        ),
        const SizedBox(height: 10),
        ConnectStatus(busy: _busy, error: _error),
        if (usb.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('SWITCH A USB DEVICE TO WI-FI', style: t.overline),
          const SizedBox(height: 8),
          for (final device in usb)
            _UsbRow(
              device: device,
              onSwitch: _busy == null ? () => _switchToWifi(device) : null,
            ),
        ],
      ],
    );
  }
}

class _UsbRow extends StatelessWidget {
  const _UsbRow({required this.device, required this.onSwitch});

  final Device device;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(LucideIcons.cable, size: 15, color: t.android),
          const SizedBox(width: 10),
          Expanded(child: Text(device.name, style: t.label)),
          Text(device.id, style: t.mono),
          const SizedBox(width: 10),
          SimuButton(
            label: 'Use Wi-Fi',
            icon: LucideIcons.wifi,
            onPressed: onSwitch,
          ),
        ],
      ),
    );
  }
}
