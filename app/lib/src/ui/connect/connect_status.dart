import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_app/src/ui/design/design.dart';

/// One line under a connect form: a spinner with [busy], else [error] in
/// red, else nothing.
class ConnectStatus extends StatelessWidget {
  const ConnectStatus({super.key, this.busy, this.error});

  final String? busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    if (busy case final message?) {
      return Row(
        children: [
          const SimuSpinner(),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: t.caption)),
        ],
      );
    }
    if (error case final message?) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.triangleAlert, size: 14, color: t.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.trim(),
              style: t.caption.copyWith(color: t.danger),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

/// A muted "where to tap on the phone" hint.
class PhoneHint extends StatelessWidget {
  const PhoneHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(LucideIcons.smartphone, size: 14, color: t.textFaint),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: t.caption)),
      ],
    );
  }
}
