import 'package:flutter/material.dart';
import 'package:simutil_app/src/ui/design/hoverable.dart';
import 'package:simutil_app/src/ui/design/surfaces.dart';
import 'package:simutil_app/src/ui/design/tokens.dart';

/// Borderless icon button: background only on hover, accent tint when
/// [active].
class SimuIconButton extends StatelessWidget {
  const SimuIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.active = false,
    this.color,
    this.size = 16,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

  /// Overrides the icon color (e.g. danger while recording).
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: SimuHoverable(
          onTap: onPressed,
          builder: (context, hovered) => AnimatedContainer(
            duration: SimuTokens.motion,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: active
                  ? t.accent.withValues(alpha: 0.14)
                  : hovered && enabled
                  ? t.hover
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(
                SimuToolbarScope.of(context) ? 999 : SimuTokens.radius,
              ),
            ),
            child: Icon(
              icon,
              size: size,
              color: !enabled
                  ? t.textFaint
                  : color ??
                        (active
                            ? t.accent
                            : hovered
                            ? t.text
                            : t.textMuted),
            ),
          ),
        ),
      ),
    );
  }
}
