import 'package:flutter/material.dart';
import 'package:simutil_app/src/ui/design/tokens.dart';

/// A bordered card on the page background.
class SimuPanel extends StatelessWidget {
  const SimuPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.panel,
        borderRadius: BorderRadius.circular(SimuTokens.radiusLarge),
        border: Border.all(color: t.border),
      ),
      child: child,
    );
  }
}

/// A capsule holding a row of [SimuIconButton]s.
class SimuToolbar extends StatelessWidget {
  const SimuToolbar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.panel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.border),
      ),
      child: SimuToolbarScope(
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

/// Marks buttons as living inside a [SimuToolbar] so their hover / active
/// background follows the capsule's round ends.
class SimuToolbarScope extends InheritedWidget {
  const SimuToolbarScope({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SimuToolbarScope>() != null;

  @override
  bool updateShouldNotify(SimuToolbarScope oldWidget) => false;
}

/// Thin vertical separator inside a [SimuToolbar].
class SimuToolbarDivider extends StatelessWidget {
  const SimuToolbarDivider({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 16,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: SimuTokens.of(context).border,
  );
}
