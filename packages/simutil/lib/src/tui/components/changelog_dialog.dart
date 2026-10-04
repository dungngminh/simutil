import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/src/tui/components/show_overlay_dialog.dart';
import 'package:simutil/src/tui/components/simutil_theme.dart';
import 'package:simutil_shared/simutil_shared.dart';

/// Scrollable release-notes overlay.
class ChangelogDialog extends StatefulComponent {
  /// Creates a changelog dialog.
  const ChangelogDialog({
    super.key,
    required this.entries,
    required this.onDismiss,
  });

  /// Changelog sections to display.
  final List<ChangelogEntry> entries;

  /// Called when the user closes the dialog.
  final VoidCallback onDismiss;

  @override
  State<ChangelogDialog> createState() => _ChangelogDialogState();
}

class _ChangelogDialogState extends State<ChangelogDialog> {
  final ScrollController _scrollController = ScrollController();

  List<_ChangelogLine> get _lines => [
    for (final entry in component.entries) ...[
      _ChangelogLine('${entry.version} — ${entry.date}', isHeader: true),
      for (final item in entry.items) _ChangelogLine(item, isItem: true),
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
                      if (line.isItem) return _ChangelogItem(line.text);
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

    // Scroll the viewport itself: there is no visible cursor, so moving a
    // hidden index only scrolled once it passed the bottom edge.
    switch (event.logicalKey) {
      case LogicalKey.arrowUp:
        _scrollController.scrollUp();
      case LogicalKey.arrowDown:
        _scrollController.scrollDown();
      default:
        return false;
    }
    return true;
  }
}

class _ChangelogLine {
  const _ChangelogLine(this.text, {this.isHeader = false, this.isItem = false});

  final String text;
  final bool isHeader;
  final bool isItem;
}

/// One bullet; renders its inline markdown (`**bold**`, `` `code` ``, links).
class _ChangelogItem extends StatelessComponent {
  const _ChangelogItem(this.text);

  final String text;

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;
    // Markdown trims leading spaces, so indent with padding instead.
    return Padding(
      padding: EdgeInsets.only(left: 2),
      child: MarkdownText(
        '• $text',
        styleSheet: MarkdownStyleSheet(
          paragraphStyle: st.body,
          boldStyle: st.bold,
          italicStyle: const TextStyle(fontStyle: FontStyle.italic),
          codeStyle: TextStyle(color: st.secondary),
          linkStyle: TextStyle(color: st.primary),
        ),
      ),
    );
  }
}

/// Shows a [ChangelogDialog] and completes when dismissed.
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
