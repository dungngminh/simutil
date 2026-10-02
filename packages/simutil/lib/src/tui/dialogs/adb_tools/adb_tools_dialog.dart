import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/src/tui/components/show_overlay_dialog.dart';
import 'package:simutil/src/tui/components/simutil_icons.dart';
import 'package:simutil/src/tui/components/simutil_theme.dart';

/// ADB wireless pairing and connection options.
enum AdbToolOption {
  /// Connect to an already-paired device by IP address.
  connectViaIp(
    label: 'Connect via IP',
    description: 'Connect to already-paired device (e.g., 192.168.1.100:5555)',
  ),

  /// Pair a device using a six-digit pairing code.
  pairWithPairingCode(
    label: 'Pair using Pairing Code',
    description: 'Pair using pairing code for wireless debugging (Android 11+)',
  ),

  /// Pair a device by scanning a QR code.
  pairWithQrCode(
    label: 'Pair using QR Code',
    description: 'Pair using QR code for wireless debugging (Android 11+)',
  );

  /// Creates an option with [label] and [description].
  const AdbToolOption({required this.label, required this.description});

  /// Short menu label.
  final String label;

  /// Longer help text shown beneath the label.
  final String description;
}

/// Menu dialog for selecting an ADB tool action.
class AdbToolsDialog extends StatefulComponent {
  /// Creates the dialog with [onSelect] and [onCancel] callbacks.
  const AdbToolsDialog({
    super.key,
    required this.onSelect,
    required this.onCancel,
  });

  /// Called when the user confirms an option.
  final void Function(AdbToolOption option) onSelect;

  /// Called when the user dismisses the dialog.
  final VoidCallback onCancel;

  @override
  State<AdbToolsDialog> createState() => _AdbToolsDialogState();
}

class _AdbToolsDialogState extends State<AdbToolsDialog> {
  int _selectedIndex = 0;

  List<AdbToolOption> get _options => AdbToolOption.values;

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;

    return Center(
      child: Container(
        color: st.background,
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

/// Shows the ADB tools menu and returns the chosen option.
Future<AdbToolOption?> showAdbToolsDialog(BuildContext context) =>
    showOverlayDialog(
      context: context,
      builder: (context, completer, entry) {
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
