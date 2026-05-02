import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/simutil_theme.dart';

class PinCodeFields extends StatelessComponent {
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

  final String label;
  final bool groupFocused;
  final CrossAxisAlignment crossAxisAlignment;
  final double spacing;
  final double cellSpacing;
  final List<TextEditingController> pinControllers;
  final int focusedPinIndex;
  final void Function(int index, String value) onPinChanged;
  final bool Function(int index, KeyboardEvent event) onPinKeyEvent;
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
