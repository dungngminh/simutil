import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/simutil_icons.dart';
import 'package:simutil/components/simutil_theme.dart';

enum AdbToolOption {
  connectViaIp(
    label: 'Connect via IP',
    description: 'Connect to already-paired device (e.g., 192.168.1.100:5555)',
  ),
  connectViaPairCode(
    label: 'Connect via Pair Code',
    description: 'Pair with 6-digit code (Android 11+)',
  ),
  connectViaQr(
    label: 'Connect via QR Code',
    description: 'Scan QR code for wireless debugging (Android 11+)',
  );

  final String label;
  final String description;

  const AdbToolOption({required this.label, required this.description});
}

class AdbToolsDialog extends StatefulComponent {
  final void Function(AdbToolOption option) onSelect;
  final VoidCallback onCancel;

  const AdbToolsDialog({
    super.key,
    required this.onSelect,
    required this.onCancel,
  });

  @override
  State<AdbToolsDialog> createState() => _AdbToolsDialogState();
}

class _AdbToolsDialogState extends State<AdbToolsDialog> {
  int _selectedIndex = 0;

  List<AdbToolOption> get _options => AdbToolOption.values;

  @override
  Component build(BuildContext context) {
    final st = SimutilTheme.of(context);

    return Center(
      child: Container(
        margin: EdgeInsets.all(16),
        decoration: st.dialogPanel('ADB Tools'),
        child: Padding(
          padding: EdgeInsets.all(1),
          child: Focusable(
            focused: true,
            onKeyEvent: _handleKeyEvent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._options.asMap().entries.map((entry) {
                  return _buildOption(st, entry.key, entry.value);
                }),
                Divider(),
                Text(
                  ' Navigate: <↑/↓> | Select: <enter> | Cancel: <esc>',
                  style: st.dimmed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Component _buildOption(SimutilTheme st, int index, AdbToolOption option) {
    final isSelected = _selectedIndex == index;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              isSelected ? ' ${SimutilIcons.pointer} ' : '   ',
              style: st.label,
            ),
            Text(option.label, style: isSelected ? st.selected : st.bold),
          ],
        ),
        Text('   ${option.description}', style: st.dimmed),
        SizedBox(height: 1),
      ],
    );
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.escape) {
      component.onCancel();
      return true;
    }

    if (event.logicalKey == LogicalKey.enter) {
      component.onSelect(_options[_selectedIndex]);
      return true;
    }

    if (event.logicalKey == LogicalKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1).clamp(0, _options.length - 1);
      });
      return true;
    }

    if (event.logicalKey == LogicalKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(0, _options.length - 1);
      });
      return true;
    }

    return false;
  }
}

Future<AdbToolOption?> showAdbToolsDialog({required BuildContext context}) {
  final completer = Completer<AdbToolOption?>();
  OverlayEntry? entry;

  entry = OverlayEntry(
    opaque: false,
    builder: (context) {
      return AdbToolsDialog(
        onSelect: (option) {
          completer.complete(option);
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
