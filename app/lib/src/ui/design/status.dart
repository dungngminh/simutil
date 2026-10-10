import 'package:flutter/material.dart';
import 'package:simutil_app/src/ui/design/tokens.dart';

/// A small state dot; [ring] cuts it out of the surface it sits on.
class SimuStatusDot extends StatelessWidget {
  const SimuStatusDot({
    super.key,
    required this.color,
    this.size = 7,
    this.ring,
  });

  final Color color;
  final double size;
  final Color? ring;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: SimuTokens.motion,
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: ring == null ? null : Border.all(color: ring!, width: 2),
    ),
  );
}

/// Dot plus a monospace label, e.g. `● LIVE`.
class SimuStatusPill extends StatelessWidget {
  const SimuStatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SimuStatusDot(color: color, size: 6),
          const SizedBox(width: 5),
          Text(
            label,
            style: t.mono.copyWith(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class SimuSpinner extends StatelessWidget {
  const SimuSpinner({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CircularProgressIndicator(strokeWidth: 1.6),
  );
}
