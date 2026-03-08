import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/show_overlay_dialog.dart';
import 'package:simutil/components/simutil_theme.dart';

class InputDialog extends StatefulComponent {
  final String title;
  final String label;
  final String hint;
  final String initialValue;
  final void Function(String value) onSubmit;
  final VoidCallback onCancel;

  const InputDialog({
    super.key,
    required this.title,
    required this.label,
    this.hint = '',
    this.initialValue = '',
    required this.onSubmit,
    required this.onCancel,
  });

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
    final st = SimutilTheme.of(context);

    return Center(
      child: Focusable(
        focused: true,
        onKeyEvent: _handleKeyEvent,
        child: Container(
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
