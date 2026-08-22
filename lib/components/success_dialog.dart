import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/show_overlay_dialog.dart';
import 'package:simutil/components/simutil_theme.dart';

/// Success overlay. Enter or Escape dismisses.
class SuccessDialog extends StatelessComponent {
  /// Creates a success dialog.
  const SuccessDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onDismiss,
  });

  /// Dialog title.
  final String title;

  /// Success body.
  final String message;

  /// Called when the user closes the dialog.
  final VoidCallback onDismiss;

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;

    return Center(
      child: Focusable(
        focused: true,
        onKeyEvent: (event) {
          if (event.logicalKey == LogicalKey.escape ||
              event.logicalKey == LogicalKey.enter) {
            onDismiss();
            return true;
          }
          return false;
        },
        child: Container(
          margin: EdgeInsets.all(16),
          decoration: st.successDialogPanel(title),
          child: Padding(
            padding: EdgeInsets.all(1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(' $message', style: st.successStyle),
                SizedBox(height: 1),
                Divider(),
                Text(' Close: <enter> | <esc>', style: st.dimmed),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a [SuccessDialog] and completes when dismissed.
Future<void> showSuccessDialog({
  required BuildContext context,
  required String title,
  required String message,
}) => showOverlayDialog<void>(
  context: context,
  builder: (context, completer, entry) {
    return SuccessDialog(
      title: title,
      message: message,
      onDismiss: () {
        completer.complete();
        entry?.remove();
      },
    );
  },
);
