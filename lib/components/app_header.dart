import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/simutil_icons.dart';
import 'package:simutil/components/simutil_theme.dart';

class AppHeader extends StatelessComponent {
  final String themeName;

  const AppHeader({super.key, required this.themeName});

  @override
  Component build(BuildContext context) {
    final st = SimutilTheme.of(context);
    return SizedBox(
      height: 1,
      child: Row(
        children: [
          Text(' ${SimutilIcons.on} SimUtil ', style: st.sectionHeader),
          Expanded(
            child: Text('Theme: $themeName ', style: st.muted),
          ),
        ],
      ),
    );
  }
}
