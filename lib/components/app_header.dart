import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/simutil_icons.dart';
import 'package:simutil/components/simutil_theme.dart';
import 'package:simutil/utils/string_extension.dart';
import 'package:simutil/utils/version.dart';

class AppHeader extends StatelessComponent {
  const AppHeader({super.key, this.themeName});

  final String? themeName;

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;
    return SizedBox(
      height: 1,
      child: Row(
        children: [
          Text(
            ' ${SimutilIcons.on} SimUtil v$packageVersion ',
            style: st.sectionHeader,
          ),
          if (themeName != null)
            Expanded(
              child: Text('Theme: ${themeName?.capitalize}', style: st.dimmed),
            ),
        ],
      ),
    );
  }
}
