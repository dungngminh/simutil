import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_app/src/scenarios/scenario_runs_cubit.dart';
import 'package:simutil_app/src/ui/design/design.dart';

/// A step's status on its line, with what to show on hover.
typedef LineMark = ({ScenarioStatus status, String message});

/// Monospace, syntax-highlighted editor for a Maestro flow, with a gutter of
/// line numbers. Give it a [controller] (a `ScenarioSyntaxController` for
/// colors); the parent sizes it. Tab indents two spaces.
class ScenarioCodeEditor extends StatefulWidget {
  const ScenarioCodeEditor({
    super.key,
    required this.controller,
    this.readOnly = false,
    this.marks = const {},
  });

  final TextEditingController controller;
  final bool readOnly;

  /// Step statuses by 0-based line, shown in the gutter.
  final Map<int, LineMark> marks;

  @override
  State<ScenarioCodeEditor> createState() => _ScenarioCodeEditorState();
}

class _ScenarioCodeEditorState extends State<ScenarioCodeEditor> {
  final _scroll = ScrollController();
  final _field = GlobalKey();

  static const _fontSize = 13.0;
  static const _lineHeight = 1.5;
  static const _pad = EdgeInsets.fromLTRB(4, 10, 10, 10);

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

  /// The text field's render object, which knows where each line sits.
  RenderEditable? _editable() {
    RenderEditable? found;
    void visit(RenderObject o) {
      if (found != null) return;
      if (o is RenderEditable) {
        found = o;
      } else {
        o.visitChildren(visit);
      }
    }

    if (_field.currentContext?.findRenderObject() case final root?) {
      visit(root);
    }
    return found;
  }

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final style = t.mono.copyWith(
      fontSize: _fontSize,
      color: t.text,
      height: _lineHeight,
    );
    // Rebuilt on resize so the gutter re-measures rewrapped lines.
    return LayoutBuilder(
      builder: (context, _) => Container(
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
              editable: _editable,
              marks: widget.marks,
            ),
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.tab): _indent,
                  },
                  child: TextField(
                    key: _field,
                    controller: widget.controller,
                    scrollController: _scroll,
                    readOnly: widget.readOnly,
                    expands: true,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    style: style,
                    strutStyle: StrutStyle(
                      fontFamily: style.fontFamily,
                      fontFamilyFallback: style.fontFamilyFallback,
                      fontSize: _fontSize,
                      height: _lineHeight,
                      forceStrutHeight: true,
                    ),
                    cursorColor: t.accent,
                    decoration: InputDecoration.collapsed(
                      hintText: 'Maestro flow YAML',
                      hintStyle: style.copyWith(color: t.textFaint),
                    ).copyWith(contentPadding: _pad),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Line numbers beside the field's lines, measured from the field itself
/// after each layout, so soft-wrapped lines and scrolling line up; a
/// wrapped line keeps its number on its first row.
class _Gutter extends StatefulWidget {
  const _Gutter({
    required this.controller,
    required this.scroll,
    required this.editable,
    required this.marks,
  });

  final TextEditingController controller;
  final ScrollController scroll;
  final RenderEditable? Function() editable;
  final Map<int, LineMark> marks;

  @override
  State<_Gutter> createState() => _GutterState();
}

class _GutterState extends State<_Gutter> {
  /// Each line's row rect (top, height) in the gutter's coordinates.
  var _rows = const <(double, double)>[];

  late final _listenable = Listenable.merge([widget.scroll, widget.controller]);

  @override
  void initState() {
    super.initState();
    _listenable.addListener(_schedule);
    _schedule();
  }

  @override
  void didUpdateWidget(_Gutter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  @override
  void dispose() {
    _listenable.removeListener(_schedule);
    super.dispose();
  }

  void _schedule() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

  /// ponytail: measures every line, fine for flow-sized YAML; measure only
  /// the visible ones if flows get huge.
  void _measure() {
    final editable = widget.editable();
    final gutter = context.findRenderObject() as RenderBox?;
    if (!mounted || editable == null || gutter == null) return;
    if (!editable.hasSize || !gutter.hasSize) return;
    final text = widget.controller.text;
    final starts = [
      0,
      for (var i = text.indexOf('\n'); i != -1; i = text.indexOf('\n', i + 1))
        i + 1,
    ];
    final rows = [
      for (final start in starts)
        () {
          final rect = editable.getLocalRectForCaret(
            TextPosition(offset: start),
          );
          final top = gutter
              .globalToLocal(editable.localToGlobal(rect.topLeft))
              .dy;
          return (top, editable.preferredLineHeight);
        }(),
    ];
    if (!listEquals(rows, _rows)) setState(() => _rows = rows);
  }

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Container(
      width: 52,
      color: t.panel,
      child: ClipRect(
        child: Stack(
          children: [
            for (final (i, (top, height)) in _rows.indexed)
              Positioned(
                top: top,
                left: 0,
                right: 8,
                height: height,
                child: _GutterRow(line: i, mark: widget.marks[i]),
              ),
          ],
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
            style: t.mono.copyWith(
              fontSize: 11,
              color: mark?.status == ScenarioStatus.failed
                  ? t.danger
                  : t.textFaint,
            ),
          ),
        ),
      ],
    );
  }
}

/// A spinner, check, cross or minus (stopped) for [status].
class ScenarioStatusIcon extends StatelessWidget {
  const ScenarioStatusIcon({super.key, required this.status, this.size = 16});

  final ScenarioStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return switch (status) {
      ScenarioStatus.running => SimuSpinner(size: size - 2),
      ScenarioStatus.stopped => Icon(
        LucideIcons.circleMinus,
        size: size,
        color: t.textMuted,
      ),
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
