import 'package:simutil/src/version.dart';
import 'package:nocterm/nocterm.dart';
import 'package:simutil/src/tui/components/simutil_icons.dart';
import 'package:simutil/src/tui/components/simutil_theme.dart';
import 'package:simutil/src/tui/utils/string_extension.dart';
import 'package:simutil_shared/simutil_shared.dart';

/// Top bar: app name, version, theme name, and right-aligned update notice.
class AppHeader extends StatelessComponent {
  /// Creates the header. Pass [themeName] when a theme is loaded and
  /// [update] when a newer release exists.
  const AppHeader({super.key, this.themeName, this.update});

  /// Current theme id, or `null` before settings load.
  final String? themeName;

  /// Newer release, or `null` when up to date or unchecked.
  final UpdateInfo? update;

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
          Expanded(
            child: themeName != null
                ? Text('Theme: ${themeName?.capitalize}', style: st.dimmed)
                : const SizedBox(),
          ),
          if (update case final update?)
            RichText(
              text: TextSpan(
                style: st.warningStyle,
                children: [
                  TextSpan(
                    text: 'Version ${update.latestVersion} available! Run: ',
                  ),
                  TextSpan(
                    text: '${update.instruction} ',
                    style: st.warningStyle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
