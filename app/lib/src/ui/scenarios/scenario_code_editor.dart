import 'package:flutter/material.dart';
import 'package:simutil_app/src/ui/design/design.dart';

/// Monospace, syntax-highlighted editor for a Maestro flow. Give it a
/// [controller] (a `ScenarioSyntaxController` for colors); the parent sizes it.
class ScenarioCodeEditor extends StatelessWidget {
  const ScenarioCodeEditor({
    super.key,
    required this.controller,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.page,
        borderRadius: BorderRadius.circular(SimuTokens.radiusSmall),
        border: Border.all(color: t.border),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        style: t.mono.copyWith(fontSize: 12, height: 1.45),
        cursorColor: t.accent,
        decoration: InputDecoration.collapsed(
          hintText: 'Maestro flow YAML',
          hintStyle: t.mono.copyWith(fontSize: 12, color: t.textFaint),
        ),
      ),
    );
  }
}
