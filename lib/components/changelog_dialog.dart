import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/show_overlay_dialog.dart';
import 'package:simutil/components/simutil_theme.dart';
import 'package:simutil/data/changelog_entries.dart';

class ChangelogDialog extends StatefulComponent {
  const ChangelogDialog({
    super.key,
    required this.entries,
    required this.onDismiss,
  });

  final List<ChangelogEntry> entries;
  final VoidCallback onDismiss;

  @override
  State<ChangelogDialog> createState() => _ChangelogDialogState();
}

class _ChangelogDialogState extends State<ChangelogDialog> {
  final ScrollController _scrollController = ScrollController();
  int _scrollIndex = 0;

  List<_ChangelogLine> get _lines => [
    for (final entry in component.entries) ...[
      _ChangelogLine('${entry.version} — ${entry.date}', isHeader: true),
      for (final item in entry.items) _ChangelogLine('  • $item'),
      const _ChangelogLine(''),
    ],
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;
    final lines = _lines;

    return Center(
      child: Focusable(
        focused: true,
        onKeyEvent: _handleKeyEvent,
        child: Container(
          width: 100,
          height: 30,
          margin: EdgeInsets.all(16),
          decoration: st.dialogPanel('What\'s New'),
          child: Padding(
            padding: EdgeInsets.all(1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: lines.length,
                    itemBuilder: (context, index) {
                      final line = lines[index];
                      return Text(
                        line.text,
                        style: line.isHeader ? st.sectionHeader : st.body,
                      );
                    },
                  ),
                ),
                Divider(),
                Text(
                  ' Scroll: <↑/↓> | Close: <enter> | <esc>',
                  style: st.dimmed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.escape ||
        event.logicalKey == LogicalKey.enter) {
      component.onDismiss();
      return true;
    }

    final lines = _lines;
    if (event.logicalKey == LogicalKey.arrowUp) {
      _scrollIndex = (_scrollIndex - 1).clamp(0, lines.length - 1);
      _scrollController.ensureIndexVisible(index: _scrollIndex);
      return true;
    }
    if (event.logicalKey == LogicalKey.arrowDown) {
      _scrollIndex = (_scrollIndex + 1).clamp(0, lines.length - 1);
      _scrollController.ensureIndexVisible(index: _scrollIndex);
      return true;
    }
    return false;
  }
}

class _ChangelogLine {
  const _ChangelogLine(this.text, {this.isHeader = false});

  final String text;
  final bool isHeader;
}

Future<void> showChangelogDialog({
  required BuildContext context,
  required List<ChangelogEntry> entries,
}) => showOverlayDialog<void>(
  context: context,
  builder: (context, completer, entry) => ChangelogDialog(
    entries: entries,
    onDismiss: () {
      completer.complete();
      entry?.remove();
    },
  ),
);
