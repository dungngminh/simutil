import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/show_overlay_dialog.dart';
import 'package:simutil/components/simutil_theme.dart';

class WelcomeDialog extends StatelessComponent {
  const WelcomeDialog({super.key, required this.onDismiss});

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
          decoration: st.dialogPanel('Welcome to SimUtil'),
          child: Padding(
            padding: EdgeInsets.all(1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(text: ' SimUtil', style: st.sectionHeader),
                      TextSpan(
                        text:
                            ' is a terminal UI for quickly launching Android emulators and iOS simulators without leaving your terminal and more.',
                        style: st.body,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 1),
                Text(" Let's try with these shortcuts:", style: st.body),
                SizedBox(height: 1),
                Text('  • Navigate devices: <↑/↓>', style: st.body),
                Text('  • Switch panels: <tab> or <←/→>', style: st.body),
                Text(
                  '  • Launch selected device: <space> or <enter>',
                  style: st.body,
                ),
                Text('  • Refresh devices: r', style: st.body),
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

Future<void> showWelcomeDialog({required BuildContext context}) =>
    showOverlayDialog<void>(
      context: context,
      builder: (context, completer, entry) => WelcomeDialog(
        onDismiss: () {
          completer.complete();
          entry?.remove();
        },
      ),
    );
