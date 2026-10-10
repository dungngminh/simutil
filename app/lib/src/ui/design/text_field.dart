import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:simutil_app/src/ui/design/tokens.dart';

/// A 30 px input on a raised, bordered box; [trailing] sits at the end
/// (e.g. a clear button) and Escape runs [onEscape].
class SimuTextField extends StatelessWidget {
  const SimuTextField({
    super.key,
    required this.controller,
    this.hint,
    this.icon,
    this.onChanged,
    this.onSubmitted,
    this.onEscape,
    this.trailing,
    this.monospace = false,
    this.autofocus = false,
    this.keyboardType,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEscape;
  final Widget? trailing;
  final bool monospace;
  final bool autofocus;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final style = monospace
        ? t.mono.copyWith(fontSize: 13, color: t.text)
        : t.body;
    Widget field = Material(
      type: MaterialType.transparency,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        autofocus: autofocus,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: style,
        cursorColor: t.accent,
        cursorHeight: 14,
        decoration: InputDecoration.collapsed(
          hintText: hint,
          hintStyle: style.copyWith(color: t.textFaint),
        ),
      ),
    );
    if (onEscape case final escape?) {
      field = CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): escape},
        child: field,
      );
    }
    return Container(
      height: 30,
      padding: EdgeInsets.only(left: icon == null ? 10 : 8),
      decoration: BoxDecoration(
        color: t.raised,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(SimuTokens.radius),
      ),
      child: Row(
        children: [
          if (icon case final icon?) ...[
            Icon(icon, size: 14, color: t.textFaint),
            const SizedBox(width: 6),
          ],
          Expanded(child: field),
          trailing ?? const SizedBox(width: 6),
        ],
      ),
    );
  }
}
