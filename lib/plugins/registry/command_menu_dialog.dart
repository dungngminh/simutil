import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/show_overlay_dialog.dart';
import 'package:simutil/components/simutil_theme.dart';
import 'package:simutil/models/plugin_config.dart';
import 'package:simutil/plugins/registry/menu_option_row.dart';

class CommandMenuDialog extends StatefulComponent {
  const CommandMenuDialog({
    super.key,
    required this.title,
    required this.commands,
    required this.onSelect,
    required this.onCancel,
  });

  final String title;
  final List<PluginCommandConfig> commands;
  final void Function(PluginCommandConfig command) onSelect;
  final VoidCallback onCancel;

  @override
  State<CommandMenuDialog> createState() => _CommandMenuDialogState();
}

class _CommandMenuDialogState extends State<CommandMenuDialog> {
  int _selectedIndex = 0;

  List<PluginCommandConfig> get _commands => component.commands;

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;
    return Center(
      child: Container(
        color: st.background,
        margin: EdgeInsets.all(16),
        decoration: st.dialogPanel(component.title),
        child: Padding(
          padding: EdgeInsets.all(1),
          child: Focusable(
            focused: true,
            onKeyEvent: _handleKeyEvent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._commands.asMap().entries.map((entry) {
                  final command = entry.value;
                  return MenuOptionRow(
                    label: command.label,
                    description: command.description,
                    shortcut: command.shortcut,
                    isSelected: _selectedIndex == entry.key,
                  );
                }),
                Divider(),
                Text(
                  ' Navigate: <↑/↓> | Run: <enter> | Back: <esc>',
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
      if (_commands.isNotEmpty) component.onSelect(_commands[_selectedIndex]);
      return true;
    }
    if (event.logicalKey == LogicalKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1).clamp(0, _commands.length - 1);
      });
      return true;
    }
    if (event.logicalKey == LogicalKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(0, _commands.length - 1);
      });
      return true;
    }
    return false;
  }
}

Future<PluginCommandConfig?> showCommandMenuDialog({
  required BuildContext context,
  required String title,
  required List<PluginCommandConfig> commands,
}) => showOverlayDialog<PluginCommandConfig>(
  context: context,
  builder: (context, completer, entry) => CommandMenuDialog(
    title: title,
    commands: commands,
    onSelect: (command) {
      completer.complete(command);
      entry?.remove();
    },
    onCancel: () {
      completer.complete(null);
      entry?.remove();
    },
  ),
);
