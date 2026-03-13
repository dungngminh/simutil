import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/show_overlay_dialog.dart';
import 'package:simutil/components/simutil_theme.dart';

class ErrorDialog extends StatelessComponent {
  const ErrorDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onDismiss,
  });
  final String title;
  final String message;
  final VoidCallback onDismiss;

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
