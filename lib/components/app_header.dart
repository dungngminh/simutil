import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/simutil_icons.dart';
import 'package:simutil/components/simutil_theme.dart';
import 'package:simutil/utils/string_extension.dart';
import 'package:simutil/utils/version.dart';

/// Top bar: app name, version, and optional theme name.
class AppHeader extends StatelessComponent {
  /// Creates the header. Pass [themeName] when a theme is loaded.
  const AppHeader({super.key, this.themeName});

  /// Current theme id, or `null` before settings load.
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
