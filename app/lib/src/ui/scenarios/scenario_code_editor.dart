import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_app/src/scenarios/scenario_runs_cubit.dart';
import 'package:simutil_app/src/scenarios/scenario_suggest.dart';
import 'package:simutil_app/src/ui/design/design.dart';

/// A step's status on its line, with its errors (empty unless failed).
typedef LineMark = ({ScenarioStatus status, String message});

/// Monospace YAML editor with a gutter of line numbers and, per [marks],
/// each step's status beside its first line. Suggests keywords at the
/// cursor (see [scenarioSuggestions]); Up / Down pick, Enter or Tab accept,
/// Escape dismisses.
class ScenarioCodeEditor extends StatefulWidget {
  const ScenarioCodeEditor({
    super.key,
    required this.controller,
    this.marks = const {},
    this.readOnly = false,
    this.devices = const [],
  });

  final TextEditingController controller;

  /// Status by line (0-based).
  final Map<int, LineMark> marks;
  final bool readOnly;

  /// Device names offered inside `devices: [...]`.
  final List<String> devices;

  @override
  State<ScenarioCodeEditor> createState() => _ScenarioCodeEditorState();
}

class _ScenarioCodeEditorState extends State<ScenarioCodeEditor> {
  final _scroll = ScrollController();
  final _focus = FocusNode();
  ScenarioSuggestions? _suggest;
  var _picked = 0;

  /// Text the user dismissed suggestions for; they return once it changes.
  String? _dismissed;

  static const _fontSize = 13.0;
  static const _lineHeight = 1.5;
  static const _padTop = 10.0;
  static const _padLeft = 4.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
    _focus.addListener(_update);
  }

  @override
  void didUpdateWidget(ScenarioCodeEditor old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_update);
      widget.controller.addListener(_update);
    }
    if (old.readOnly != widget.readOnly || old.devices != widget.devices) {
      // After this frame: _update may setState.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _update();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _update() {
    final value = widget.controller.value;
    final sel = value.selection;
    final next =
        widget.readOnly ||
            !_focus.hasFocus ||
            !sel.isValid ||
            !sel.isCollapsed ||
            value.text == _dismissed
        ? null
        : scenarioSuggestions(
            value.text,
            sel.baseOffset,
            devices: widget.devices,
          );
    if (next?.items != _suggest?.items || next?.start != _suggest?.start) {
      setState(() {
        _suggest = next;
        _picked = 0;
      });
    }
  }

  void _accept() {
    final s = _suggest;
    if (s == null || widget.readOnly) return;
    final value = widget.controller.value;
    final insert = s.items[_picked].insert;
    widget.controller.value = value.replaced(
      TextRange(start: s.start, end: value.selection.baseOffset),
      insert,
    );
  }

  void _move(int by) =>
      setState(() => _picked = (_picked + by) % (_suggest?.items.length ?? 1));

  void _dismiss() => setState(() {
    _dismissed = widget.controller.text;
    _suggest = null;
  });

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
    final suggest = _suggest;
    final bindings = <ShortcutActivator, VoidCallback>{
      if (suggest == null)
        const SingleActivator(LogicalKeyboardKey.tab): _indent
      else ...{
        const SingleActivator(LogicalKeyboardKey.tab): _accept,
        const SingleActivator(LogicalKeyboardKey.enter): _accept,
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.escape): _dismiss,
      },
    };
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
              child: Stack(
                children: [
                  CallbackShortcuts(
                    bindings: bindings,
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
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
                      decoration:
                          const InputDecoration.collapsed(
                            hintText: null,
                          ).copyWith(
                            contentPadding: const EdgeInsets.fromLTRB(
                              _padLeft,
                              _padTop,
                              10,
                              _padTop,
                            ),
                          ),
                    ),
                  ),
                  if (suggest != null)
                    _SuggestionPopup(
                      at: _caret(style, suggest.start),
                      lineExtent: _fontSize * _lineHeight,
                      items: [for (final i in suggest.items) i.label],
                      picked: _picked,
                      onPick: (i) {
                        _picked = i;
                        _accept();
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Top-left of the character at [offset], in the text area.
  /// ponytail: monospace, no soft wrap (as the gutter assumes).
  Offset _caret(TextStyle style, int offset) {
    final text = widget.controller.text;
    final lineStart = text.lastIndexOf('\n', offset - 1) + 1;
    final line = '\n'.allMatches(text.substring(0, lineStart)).length;
    final charWidth = (TextPainter(
      text: TextSpan(text: 'M', style: style),
      textDirection: TextDirection.ltr,
    )..layout()).width;
    final scrolled = _scroll.hasClients ? _scroll.offset : 0.0;
    return Offset(
      _padLeft + (offset - lineStart) * charWidth,
      _padTop + line * _fontSize * _lineHeight - scrolled,
    );
  }
}

/// Keyword choices under the word being typed.
class _SuggestionPopup extends StatelessWidget {
  const _SuggestionPopup({
    required this.at,
    required this.lineExtent,
    required this.items,
    required this.picked,
    required this.onPick,
  });

  final Offset at;
  final double lineExtent;
  final List<String> items;
  final int picked;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Positioned(
      left: at.dx,
      top: at.dy + lineExtent + 2,
      child: Container(
        constraints: const BoxConstraints(minWidth: 140, maxHeight: 180),
        decoration: BoxDecoration(
          color: t.panel,
          borderRadius: BorderRadius.circular(SimuTokens.radiusSmall),
          border: Border.all(color: t.border),
          boxShadow: const [
            BoxShadow(color: Color(0x40000000), blurRadius: 10),
          ],
        ),
        child: SingleChildScrollView(
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, label) in items.indexed)
                  GestureDetector(
                    onTap: () => onPick(i),
                    child: Container(
                      color: i == picked ? t.hover : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Text(
                        label,
                        style: t.mono.copyWith(
                          fontSize: 12,
                          color: i == picked ? t.text : t.textMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
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

/// A spinner, check, cross, minus (skipped) or hollow circle for [status].
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
      ScenarioStatus.skipped => Icon(
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
