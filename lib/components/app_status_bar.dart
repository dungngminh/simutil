import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/simutil_theme.dart';

/// Bottom status bar displaying a single-line status message.
class AppStatusBar extends StatelessComponent {
  final String message;

  const AppStatusBar({super.key, required this.message});

  @override
  Component build(BuildContext context) {
    final st = SimutilTheme.of(context);
    return SizedBox(
      height: 1,
      child: Row(
        children: [
          Expanded(child: Text(' $message', style: st.dimmed)),
        ],
      ),
    );
  }
}
