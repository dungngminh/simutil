import 'package:flutter/widgets.dart';

/// Tracks hover and taps for custom controls; [builder] gets the hover
/// state. Disabled when [onTap] is null.
class SimuHoverable extends StatefulWidget {
  const SimuHoverable({
    super.key,
    required this.builder,
    this.onTap,
    this.onSecondaryTap,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final VoidCallback? onTap;
  final VoidCallback? onSecondaryTap;

  @override
  State<SimuHoverable> createState() => _SimuHoverableState();
}

class _SimuHoverableState extends State<SimuHoverable> {
  bool _hovered = false;

  void _hover(bool value) {
    if (_hovered != value) setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => _hover(true),
      onExit: (_) => _hover(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onSecondaryTap: widget.onSecondaryTap,
        child: widget.builder(context, _hovered),
      ),
    );
  }
}
