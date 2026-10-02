import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/src/tui/components/show_overlay_dialog.dart';
import 'package:simutil/src/tui/components/simutil_theme.dart';

/// Error overlay. Enter or Escape dismisses.
class ErrorDialog extends StatelessComponent {
  /// Creates an error dialog.
  const ErrorDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onDismiss,
  });

  /// Dialog title.
  final String title;

  /// Error body.
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
          decoration: st.errorDialogPanel(title),
          child: Padding(
            padding: EdgeInsets.all(1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(' $message', style: st.errorStyle),
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

/// Shows an [ErrorDialog] and completes when dismissed.
Future<void> showErrorDialog(
  BuildContext context, {
  required String title,
  required String message,
}) => showOverlayDialog<void>(
  context: context,
  builder: (context, completer, entry) => ErrorDialog(
    title: title,
    message: message,
    onDismiss: () {
      completer.complete();
      entry?.remove();
    },
  ),
);
