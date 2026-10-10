import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_app/src/ui/design/hoverable.dart';
import 'package:simutil_app/src/ui/design/icon_button.dart';
import 'package:simutil_app/src/ui/design/status.dart';
import 'package:simutil_app/src/ui/design/tokens.dart';

/// Toast card: raised surface with a tinted badge, a title, an optional mono
/// subtitle and actions. [busy] swaps the badge icon for a spinner.
class SimuToast extends StatelessWidget {
  const SimuToast({
    super.key,
    required this.height,
    required this.title,
    required this.icon,
    required this.tone,
    this.busy = false,
    this.subtitle,
    this.subtitleLines = 1,
    this.actions = const [],
    this.onTap,
    this.onClose,
  });

  /// Fixed height; the toast stack lays toasts out by it.
  final double height;
  final String title;
  final IconData icon;
  final Color tone;
  final bool busy;
  final String? subtitle;
  final int subtitleLines;
  final List<Widget> actions;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final subtitle = this.subtitle;
    return SimuHoverable(
      onTap: onTap,
      builder: (context, _) => Container(
        height: height,
        padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
        decoration: BoxDecoration(
          color: t.raised,
          borderRadius: BorderRadius.circular(SimuTokens.radiusLarge),
          border: Border.all(color: t.border),
          boxShadow: const [
            BoxShadow(
              blurRadius: 28,
              offset: Offset(0, 10),
              color: Color(0x40000000),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(SimuTokens.radius),
              ),
              child: busy
                  ? const SimuSpinner()
                  : Icon(icon, size: 16, color: tone),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.label,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: subtitleLines,
                      overflow: TextOverflow.ellipsis,
                      style: t.mono.copyWith(height: 1.3),
                    ),
                  ],
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(spacing: 8, children: actions),
                  ],
                ],
              ),
            ),
            if (onClose != null)
              SimuIconButton(
                icon: LucideIcons.x,
                tooltip: 'Dismiss',
                size: 14,
                onPressed: onClose,
              ),
          ],
        ),
      ),
    );
  }
}
