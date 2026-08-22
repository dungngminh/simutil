import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/simutil_icons.dart';
import 'package:simutil/components/simutil_theme.dart';

/// Single selectable row in a plugin or command menu.
class MenuOptionRow extends StatelessComponent {
  /// Creates a row with [label], optional [description], and [shortcut].
  const MenuOptionRow({
    super.key,
    required this.label,
    required this.isSelected,
    this.description,
    this.shortcut,
  });

  /// Primary option label.
  final String label;

  /// Whether this row is currently highlighted.
  final bool isSelected;

  /// Optional secondary description text.
  final String? description;

  /// Optional shortcut key shown on the right.
  final String? shortcut;

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              isSelected ? ' ${SimutilIcons.pointer} ' : '   ',
              style: st.label,
            ),
            Expanded(
              child: Text(label, style: isSelected ? st.selected : st.bold),
            ),
            if (shortcut != null) Text(' [$shortcut] ', style: st.dimmed),
          ],
        ),
        if (description != null && description!.isNotEmpty)
          Text('   $description', style: st.dimmed),
      ],
    );
  }
}
