import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/show_overlay_dialog.dart';
import 'package:simutil/components/simutil_theme.dart';

/// A simple yes/no confirmation overlay.
///
/// Enter confirms; Escape cancels.
class ConfirmDialog extends StatelessComponent {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
    required this.onCancel,
  });

  final String title;
  final String message;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;

    return Center(
      child: Focusable(
        focused: true,
        onKeyEvent: _handleKeyEvent,
        child: Container(
          margin: EdgeInsets.all(16),
          decoration: st.dialogPanel(title),
          child: Padding(
            padding: EdgeInsets.all(1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(' $message', style: st.body),
                SizedBox(height: 1),
                Divider(),
                Text(' Confirm: <enter> | Cancel: <esc>', style: st.dimmed),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.escape) {
      onCancel();
      return true;
    }
    if (event.logicalKey == LogicalKey.enter) {
      onConfirm();
      return true;
    }
    return false;
  }
}

Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
}) async {
  final result = await showOverlayDialog<bool>(
    context: context,
    builder: (context, completer, entry) {
      return ConfirmDialog(
        title: title,
        message: message,
        onConfirm: () {
          completer.complete(true);
          entry?.remove();
        },
        onCancel: () {
          completer.complete(false);
          entry?.remove();
        },
      );
    },
  );
  return result ?? false;
}
