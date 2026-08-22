import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/simutil_theme.dart';

/// Row of single-character PIN input cells.
class PinCodeFields extends StatelessComponent {
  /// Creates a labeled PIN entry row.
  const PinCodeFields({
    required this.label,
    required this.groupFocused,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.spacing = 1.0,
    this.cellSpacing = 1.0,
    required this.pinControllers,
    required this.focusedPinIndex,
    required this.onPinChanged,
    required this.onPinKeyEvent,
    required this.onSubmitted,
  });

  /// Label shown above the PIN cells.
  final String label;

  /// Whether the PIN group is focused in the parent form.
  final bool groupFocused;

  /// Horizontal alignment of the label and cells.
  final CrossAxisAlignment crossAxisAlignment;

  /// Vertical gap between label and cells.
  final double spacing;

  /// Horizontal gap between PIN cells.
  final double cellSpacing;

  /// One controller per PIN digit cell.
  final List<TextEditingController> pinControllers;

  /// Index of the cell that should show focus styling.
  final int focusedPinIndex;

  /// Called when a cell's value changes.
  final void Function(int index, String value) onPinChanged;

  /// Called for key events on a cell; return `true` if handled.
  final bool Function(int index, KeyboardEvent event) onPinKeyEvent;

  /// Called when the user submits the full PIN.
  final VoidCallback onSubmitted;

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(' $label', style: groupFocused ? st.label : st.body),
        SizedBox(height: spacing),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('  ', style: st.body),
            ...List.generate(pinControllers.length, (index) {
              return Row(
                children: [
                  _PinCell(
                    controller: pinControllers[index],
                    focused: groupFocused && focusedPinIndex == index,
                    onChanged: (value) => onPinChanged(index, value),
                    onSubmitted: onSubmitted,
                    onKeyEvent: (event) => onPinKeyEvent(index, event),
                  ),
                  if (index < pinControllers.length - 1)
                    SizedBox(width: cellSpacing),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }
}

class _PinCell extends StatelessComponent {
  const _PinCell({
    required this.controller,
    required this.focused,
    required this.onChanged,
    required this.onSubmitted,
    required this.onKeyEvent,
  });

  final TextEditingController controller;
  final bool focused;
  final void Function(String value) onChanged;
  final VoidCallback onSubmitted;
  final bool Function(KeyboardEvent event) onKeyEvent;

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;
    return Container(
      width: 5,
      height: 3,
      child: TextField(
        controller: controller,
        focused: focused,
        placeholder: '',
        placeholderStyle: st.dimmed,
        style: TextStyle(fontWeight: FontWeight.bold, color: st.onSurface),
        showCursor: false,
        textAlign: TextAlign.center,
        onChanged: onChanged,
        onSubmitted: (_) => onSubmitted(),
        onKeyEvent: onKeyEvent,
        decoration: InputDecoration(
          border: BoxBorder.all(
            style: BoxBorderStyle.rounded,
            color: st.outline,
          ),
          focusedBorder: BoxBorder.all(
            style: BoxBorderStyle.rounded,
            color: st.primary,
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
