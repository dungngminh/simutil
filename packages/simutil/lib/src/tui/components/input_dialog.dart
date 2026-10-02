import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/src/tui/components/show_overlay_dialog.dart';
import 'package:simutil/src/tui/components/simutil_theme.dart';

/// Single-line text input overlay.
class InputDialog extends StatefulComponent {
  /// Creates an input dialog.
  const InputDialog({
    super.key,
    required this.title,
    required this.label,
    this.hint = '',
    this.initialValue = '',
    required this.onSubmit,
    required this.onCancel,
  });

  /// Dialog title.
  final String title;

  /// Label above the text field.
  final String label;

  /// Optional hint shown below the field.
  final String hint;

  /// Initial text field value.
  final String initialValue;

  /// Called with the trimmed value on Enter.
  final void Function(String value) onSubmit;

  /// Called when the user cancels.
  final VoidCallback onCancel;

  @override
  State<InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<InputDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: component.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.escape) {
      component.onCancel();
      return true;
    }
    return false;
  }

  void _handleSubmit(String value) {
    if (value.isNotEmpty) {
      component.onSubmit(value);
    }
  }

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;

    return Center(
      child: Focusable(
        focused: true,
        onKeyEvent: _handleKeyEvent,
        child: Container(
          constraints: BoxConstraints(minWidth: 50, maxWidth: 120),
          margin: EdgeInsets.all(16),
          decoration: st.dialogPanel(component.title),
          child: Padding(
            padding: EdgeInsets.all(1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(' ${component.label}', style: st.label),
                SizedBox(height: 1),
                _buildInputField(st),
                if (component.hint.isNotEmpty) ...[
                  SizedBox(height: 1),
                  Text(' ${component.hint}', style: st.dimmed),
                ],
                Divider(),
                Text(' Submit: <enter> | Cancel: <esc>', style: st.dimmed),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Component _buildInputField(SimutilTheme st) {
    return TextField(
      controller: _controller,
      focused: true,
      onSubmitted: _handleSubmit,
      style: st.body,
      decoration: InputDecoration(
        border: BoxBorder.all(style: BoxBorderStyle.rounded, color: st.outline),
        focusedBorder: BoxBorder.all(
          style: BoxBorderStyle.rounded,
          color: st.primary,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 1),
      ),
    );
  }
}

/// Shows an [InputDialog]; returns the submitted value or `null`.
Future<String?> showInputDialog({
  required BuildContext context,
  required String title,
  required String label,
  String hint = '',
  String initialValue = '',
}) => showOverlayDialog<String?>(
  context: context,
  builder: (context, completer, entry) {
    return InputDialog(
      title: title,
      label: label,
      hint: hint,
      initialValue: initialValue,
      onSubmit: (value) {
        completer.complete(value);
        entry?.remove();
      },
      onCancel: () {
        completer.complete(null);
        entry?.remove();
      },
    );
  },
);
