import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/simutil_theme.dart';

/// Filter label and text field used by the logcat dialog.
class LogcatFilterBar extends StatelessComponent {
  /// Creates a filter bar bound to [controller].
  const LogcatFilterBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onKeyEvent,
  });

  /// Text field controller for the filter expression.
  final TextEditingController controller;

  /// Called when the filter text changes.
  final ValueChanged<String> onChanged;

  /// Handles keyboard events while the filter field is focused.
  final bool Function(KeyboardEvent event) onKeyEvent;

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;
    return Column(
      children: [
        Row(
          children: [
            Text(' Filter: ', style: st.label),
            Expanded(
              child: TextField(
                controller: controller,
                focused: true,
                onChanged: onChanged,
                onKeyEvent: onKeyEvent,
                style: st.body,
                decoration: InputDecoration(
                  border: BoxBorder.all(
                    style: BoxBorderStyle.rounded,
                    color: st.outline,
                  ),
                  focusedBorder: BoxBorder.all(
                    style: BoxBorderStyle.rounded,
                    color: st.primary,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 1),
                ),
              ),
            ),
          ],
        ),
        Text(
          'Quick: is:crash · is:error · is:warn · is:info · is:debug · is:verbose'
          ' | Close: <esc> ',
          style: st.dimmed,
        ),
      ],
    );
  }
}
