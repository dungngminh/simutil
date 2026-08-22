import 'package:nocterm/nocterm.dart';

/// One-line footer showing the latest status [message].
class AppStatusBar extends StatelessComponent {
  /// Creates a status bar.
  const AppStatusBar({super.key, required this.message});

  /// Text shown in the footer.
  final String message;

  @override
  Component build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: Row(
        children: [
          Expanded(child: Text(' $message')),
        ],
      ),
    );
  }
}
