import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/simutil_icons.dart';
import 'package:simutil/components/simutil_theme.dart';

class MenuOptionRow extends StatelessComponent {
  const MenuOptionRow({
    super.key,
    required this.label,
    required this.isSelected,
    this.description,
    this.shortcut,
  });

  final String label;
  final bool isSelected;
  final String? description;
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
