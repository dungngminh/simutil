import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/show_overlay_dialog.dart';
import 'package:simutil/components/simutil_icons.dart';
import 'package:simutil/components/simutil_theme.dart';

enum XcodeToolOption {
  clearDerivedData(
    label: 'Clear Derived Data',
    description:
        'Delete all of ~/Library/Developer/Xcode/DerivedData'
  );

  const XcodeToolOption({required this.label, required this.description});

  final String label;
  final String description;
}

class XcodeToolsDialog extends StatefulComponent {
  const XcodeToolsDialog({
    super.key,
    required this.onSelect,
    required this.onCancel,
  });

  final void Function(XcodeToolOption option) onSelect;
  final VoidCallback onCancel;

  @override
  State<XcodeToolsDialog> createState() => _XcodeToolsDialogState();
}

class _XcodeToolsDialogState extends State<XcodeToolsDialog> {
  int _selectedIndex = 0;

  List<XcodeToolOption> get _options => XcodeToolOption.values;

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;

    return Center(
      child: Container(
        color: st.background,
        margin: EdgeInsets.all(16),
        decoration: st.dialogPanel('Xcode Tools'),
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

  Component _buildOption(SimutilTheme st, int index, XcodeToolOption option) {
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

Future<XcodeToolOption?> showXcodeToolsDialog(BuildContext context) =>
    showOverlayDialog(
      context: context,
      builder: (context, completer, entry) {
        return XcodeToolsDialog(
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
