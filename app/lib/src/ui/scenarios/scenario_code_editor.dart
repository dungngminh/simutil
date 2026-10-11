import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_app/src/scenarios/scenario_runs_cubit.dart';
import 'package:simutil_app/src/ui/design/design.dart';

/// A step's status on its line, with its errors (empty unless failed).
typedef LineMark = ({ScenarioStatus status, String message});

/// Monospace YAML editor with a gutter of line numbers and, per [marks],
/// each step's status beside its first line.
class ScenarioCodeEditor extends StatefulWidget {
  const ScenarioCodeEditor({
    super.key,
    required this.controller,
    this.marks = const {},
    this.readOnly = false,
  });

  final TextEditingController controller;

  /// Status by line (0-based).
  final Map<int, LineMark> marks;
  final bool readOnly;

  @override
  State<ScenarioCodeEditor> createState() => _ScenarioCodeEditorState();
}

class _ScenarioCodeEditorState extends State<ScenarioCodeEditor> {
  final _scroll = ScrollController();

  static const _fontSize = 13.0;
  static const _lineHeight = 1.5;
  static const _padTop = 10.0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _indent() {
    final sel = widget.controller.selection;
    if (widget.readOnly || !sel.isValid) return;
    widget.controller.value = widget.controller.value.replaced(sel, '  ');
  }

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final style = t.mono.copyWith(
      fontSize: _fontSize,
      color: t.text,
      height: _lineHeight,
    );
    return Container(
      decoration: BoxDecoration(
        color: t.raised,
        borderRadius: BorderRadius.circular(SimuTokens.radius),
        border: Border.all(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Gutter(
            controller: widget.controller,
            scroll: _scroll,
            marks: widget.marks,
            lineExtent: _fontSize * _lineHeight,
            padTop: _padTop,
          ),
          Expanded(
            child: Material(
              type: MaterialType.transparency,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.tab): _indent,
                },
                child: TextField(
                  controller: widget.controller,
                  scrollController: _scroll,
                  readOnly: widget.readOnly,
                  expands: true,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: style,
                  // Every line exactly one gutter row tall.
                  strutStyle: StrutStyle(
                    fontFamily: style.fontFamily,
                    fontFamilyFallback: style.fontFamilyFallback,
                    fontSize: _fontSize,
                    height: _lineHeight,
                    forceStrutHeight: true,
                  ),
                  cursorColor: t.accent,
                  decoration: const InputDecoration.collapsed(hintText: null)
                      .copyWith(
                        contentPadding: const EdgeInsets.fromLTRB(
                          4,
                          _padTop,
                          10,
                          _padTop,
                        ),
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Line numbers and step statuses, scrolled with the text.
/// ponytail: rows assume no soft wrap; YAML steps are short lines.
class _Gutter extends StatelessWidget {
  const _Gutter({
    required this.controller,
    required this.scroll,
    required this.marks,
    required this.lineExtent,
    required this.padTop,
  });

  final TextEditingController controller;
  final ScrollController scroll;
  final Map<int, LineMark> marks;
  final double lineExtent;
  final double padTop;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Container(
      width: 52,
      color: t.panel,
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, box) => ListenableBuilder(
            listenable: Listenable.merge([scroll, controller]),
            builder: (context, _) {
              final offset = scroll.hasClients ? scroll.offset : 0.0;
              final lines = '\n'.allMatches(controller.text).length + 1;
              final first = ((offset - padTop) / lineExtent).floor().clamp(
                0,
                lines,
              );
              final last = ((offset + box.maxHeight) / lineExtent).ceil().clamp(
                0,
                lines,
              );
              return Stack(
                children: [
                  for (var i = first; i < last; i++)
                    Positioned(
                      top: padTop + i * lineExtent - offset,
                      left: 0,
                      right: 6,
                      height: lineExtent,
                      child: _GutterRow(line: i, mark: marks[i]),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GutterRow extends StatelessWidget {
  const _GutterRow({required this.line, this.mark});

  final int line;
  final LineMark? mark;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final mark = this.mark;
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: mark == null
              ? null
              : Center(
                  child: Tooltip(
                    message: mark.message,
                    child: ScenarioStatusIcon(status: mark.status, size: 13),
                  ),
                ),
        ),
        Expanded(
          child: Text(
            '${line + 1}',
            textAlign: TextAlign.right,
            style: t.mono.copyWith(fontSize: 11, color: t.textFaint),
          ),
        ),
      ],
    );
  }
}

/// A spinner, check, cross or hollow circle for [status].
class ScenarioStatusIcon extends StatelessWidget {
  const ScenarioStatusIcon({super.key, required this.status, this.size = 16});

  final ScenarioStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return switch (status) {
      ScenarioStatus.pending => Icon(
        LucideIcons.circle,
        size: size,
        color: t.textFaint,
      ),
      ScenarioStatus.running => SimuSpinner(size: size - 2),
      ScenarioStatus.ok => Icon(
        LucideIcons.circleCheck,
        size: size,
        color: t.success,
      ),
      ScenarioStatus.failed => Icon(
        LucideIcons.circleX,
        size: size,
        color: t.danger,
      ),
    };
  }
}
