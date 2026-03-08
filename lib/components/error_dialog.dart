import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/simutil_theme.dart';

/// A modal error dialog that displays an error message.
///
/// Use [showErrorDialog] to display this as an overlay.
class ErrorDialog extends StatelessComponent {
  final String title;
  final String message;
  final VoidCallback onDismiss;

  const ErrorDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onDismiss,
  });

  @override
  Component build(BuildContext context) {
    final st = SimutilTheme.of(context);

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
          decoration: BoxDecoration(
            border: BoxBorder.all(
              style: BoxBorderStyle.rounded,
              color: st.error,
            ),
            title: BorderTitle(text: title),
            color: st.background,
          ),
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

/// Show an error dialog as a modal overlay.
///
/// Returns when the user dismisses the dialog.
Future<void> showErrorDialog({
  required BuildContext context,
  required String title,
  required String message,
}) {
  final completer = Completer<void>();
  OverlayEntry? entry;

  entry = OverlayEntry(
    opaque: false,
    builder: (context) {
      return ErrorDialog(
        title: title,
        message: message,
        onDismiss: () {
          completer.complete();
          entry?.remove();
        },
      );
    },
  );

  Overlay.of(context).insert(entry);

  return completer.future;
}
