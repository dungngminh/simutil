import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_app/src/ui/design/design.dart';

/// Filters the device list by name; the clear button and Escape empty it.
class DeviceSearchField extends StatefulWidget {
  const DeviceSearchField({super.key, required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<DeviceSearchField> createState() => _DeviceSearchFieldState();
}

class _DeviceSearchFieldState extends State<DeviceSearchField> {
  final _controller = TextEditingController();

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SimuTextField(
    controller: _controller,
    hint: 'Search devices',
    icon: LucideIcons.search,
    onChanged: widget.onChanged,
    onEscape: _clear,
    trailing: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _controller.text.isEmpty
          ? const SizedBox(width: 6)
          : SimuIconButton(
              icon: LucideIcons.x,
              tooltip: 'Clear',
              size: 13,
              onPressed: _clear,
            ),
    ),
  );
}
