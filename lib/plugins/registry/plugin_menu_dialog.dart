import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/show_overlay_dialog.dart';
import 'package:simutil/components/simutil_theme.dart';
import 'package:simutil/models/plugin_config.dart';
import 'package:simutil/plugins/registry/menu_option_row.dart';

class PluginMenuDialog extends StatefulComponent {
  const PluginMenuDialog({
    super.key,
    required this.plugins,
    required this.onSelect,
    required this.onCancel,
  });

  final List<PluginConfig> plugins;
  final void Function(PluginConfig plugin) onSelect;
  final VoidCallback onCancel;

  @override
  State<PluginMenuDialog> createState() => _PluginMenuDialogState();
}

class _PluginMenuDialogState extends State<PluginMenuDialog> {
  int _selectedIndex = 0;

  List<PluginConfig> get _plugins => component.plugins;

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;
    return Center(
      child: Container(
        color: st.background,
        margin: EdgeInsets.all(16),
        decoration: st.dialogPanel('Plugins'),
        child: Padding(
          padding: EdgeInsets.all(1),
          child: Focusable(
            focused: true,
            onKeyEvent: _handleKeyEvent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._plugins.asMap().entries.map((entry) {
                  final plugin = entry.value;
                  return MenuOptionRow(
                    label: plugin.label,
                    description: plugin.description,
                    shortcut: plugin.shortcut,
                    isSelected: _selectedIndex == entry.key,
                  );
                }),
                Divider(),
                Text(
                  ' Navigate: <↑/↓> | Select: <enter> | Cancel: <esc>',
                  style: st.dimmed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.escape) {
      component.onCancel();
      return true;
    }
    if (event.logicalKey == LogicalKey.enter) {
      if (_plugins.isNotEmpty) component.onSelect(_plugins[_selectedIndex]);
      return true;
    }
    if (event.logicalKey == LogicalKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1).clamp(0, _plugins.length - 1);
      });
      return true;
    }
    if (event.logicalKey == LogicalKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(0, _plugins.length - 1);
      });
      return true;
    }
    return false;
  }
}

Future<PluginConfig?> showPluginMenuDialog({
  required BuildContext context,
  required List<PluginConfig> plugins,
}) => showOverlayDialog<PluginConfig>(
  context: context,
  builder: (context, completer, entry) => PluginMenuDialog(
    plugins: plugins,
    onSelect: (plugin) {
      completer.complete(plugin);
      entry?.remove();
    },
    onCancel: () {
      completer.complete(null);
      entry?.remove();
    },
  ),
);
