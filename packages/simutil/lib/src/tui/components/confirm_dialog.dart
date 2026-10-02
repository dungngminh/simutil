import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/src/tui/components/show_overlay_dialog.dart';
import 'package:simutil/src/tui/components/simutil_theme.dart';

/// A simple yes/no confirmation overlay.
///
/// Enter confirms; Escape cancels.
class ConfirmDialog extends StatelessComponent {
  /// Creates a confirmation dialog.
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
    required this.onCancel,
  });

  /// Dialog title.
  final String title;

  /// Confirmation prompt body.
  final String message;

  /// Called when the user confirms.
  final VoidCallback onConfirm;

  /// Called when the user cancels.
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

/// Shows a [ConfirmDialog]; returns `true` if confirmed.
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
