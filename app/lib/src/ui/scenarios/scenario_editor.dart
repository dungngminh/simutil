import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_app/src/di.dart';
import 'package:simutil_app/src/mcp/tools/input_tools.dart';
import 'package:simutil_app/src/mcp/tools/tool_context.dart';
import 'package:simutil_app/src/scenarios/scenario_yaml.dart';
import 'package:simutil_app/src/ui/design/design.dart';

/// Opens the scenario editor: write YAML or open a file, then run it; its
/// progress shows in the scenarios panel.
Future<void> showScenarioEditor(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _ScenarioEditor());

/// What was in the editor when it last closed, so a draft survives.
/// ponytail: in memory only; save to a file with Open file's twin if needed.
String _draft = scenarioTemplate;

class _ScenarioEditor extends StatefulWidget {
  const _ScenarioEditor();

  @override
  State<_ScenarioEditor> createState() => _ScenarioEditorState();
}

class _ScenarioEditorState extends State<_ScenarioEditor> {
  late final _text = TextEditingController(text: _draft);
  String? _error;
  String? _file;

  @override
  void dispose() {
    _draft = _text.text;
    _text.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Scenario', extensions: ['yaml', 'yml']),
      ],
    );
    if (file == null) return;
    final text = await File(file.path).readAsString();
    setState(() {
      _text.text = text;
      _file = file.name;
      _error = null;
    });
  }

  void _run() {
    final Map<String, Object?> args;
    final ToolContext tools;
    try {
      args = scenarioFromYaml(_text.text);
      tools = getIt<ToolContext>();
      parseScenario(tools, args);
    } on FormatException catch (e) {
      return setState(() => _error = e.message);
    } on ArgumentError catch (e) {
      return setState(() => _error = '${e.message}');
    }
    Navigator.of(context).pop();
    unawaited(
      runScenario(tools, args).then<void>(
        (_) {},
        onError: (Object e) =>
            tools.devices.notify('Scenario failed: $e', error: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Dialog(
      backgroundColor: t.panel,
      child: SizedBox(
        width: 640,
        height: 560,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _EditorHeader(file: _file),
              const SizedBox(height: 12),
              Expanded(child: _YamlField(controller: _text)),
              if (_error case final error?) _ErrorLine(error: error),
              const SizedBox(height: 12),
              _EditorActions(onOpen: _open, onRun: _run),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({this.file});

  final String? file;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Row(
      children: [
        Text('Scenario', style: t.title),
        const SizedBox(width: 8),
        if (file != null) Text(file!, style: t.caption),
        const Spacer(),
        SimuIconButton(
          icon: LucideIcons.x,
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// The YAML source: monospace, multi-line, tab inserts two spaces.
class _YamlField extends StatelessWidget {
  const _YamlField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.raised,
        borderRadius: BorderRadius.circular(SimuTokens.radius),
        border: Border.all(color: t.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.tab): _indent},
          child: TextField(
            controller: controller,
            autofocus: true,
            expands: true,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            style: t.mono.copyWith(fontSize: 13, color: t.text, height: 1.45),
            cursorColor: t.accent,
            decoration: const InputDecoration.collapsed(hintText: null),
          ),
        ),
      ),
    );
  }

  void _indent() {
    final sel = controller.selection;
    if (!sel.isValid) return;
    controller.value = controller.value.replaced(sel, '  ');
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.circleX, size: 14, color: t.danger),
          const SizedBox(width: 6),
          Expanded(
            child: SelectableText(
              error,
              style: t.caption.copyWith(color: t.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorActions extends StatelessWidget {
  const _EditorActions({required this.onOpen, required this.onRun});

  final VoidCallback onOpen;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SimuButton(
          label: 'Open file…',
          icon: LucideIcons.folderOpen,
          onPressed: onOpen,
        ),
        const Spacer(),
        SimuButton(
          label: 'Run',
          icon: LucideIcons.play,
          primary: true,
          onPressed: onRun,
        ),
      ],
    );
  }
}
