import 'package:nocterm/nocterm.dart';

class AppStatusBar extends StatelessComponent {
  const AppStatusBar({super.key, required this.message});

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
