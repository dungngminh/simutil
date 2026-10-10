import 'package:flutter/material.dart';
import 'package:simutil_app/src/ui/design/hoverable.dart';
import 'package:simutil_app/src/ui/design/tokens.dart';

/// Compact text button: filled accent ([primary]) or a quiet raised one.
class SimuButton extends StatelessWidget {
  const SimuButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final foreground = primary ? t.onAccent : t.text;
    return SimuHoverable(
      onTap: onPressed,
      builder: (context, hovered) => AnimatedOpacity(
        duration: SimuTokens.motion,
        opacity: onPressed == null ? 0.5 : (hovered ? 0.88 : 1),
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: primary ? t.accent : t.raised,
            borderRadius: BorderRadius.circular(SimuTokens.radiusSmall),
            border: primary ? null : Border.all(color: t.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon case final icon?) ...[
                Icon(icon, size: 12, color: foreground),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
