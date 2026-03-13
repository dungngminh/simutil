import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/show_overlay_dialog.dart';
import 'package:simutil/components/simutil_icons.dart';
import 'package:simutil/components/simutil_theme.dart';
import 'package:simutil/models/android_quick_launch_option.dart';
import 'package:simutil/models/device.dart';

class AndroidLaunchDialog extends StatefulComponent {
  const AndroidLaunchDialog({
    super.key,
    required this.device,
    required this.onLaunch,
    required this.onCancel,
  });
  
  final Device device;

  final void Function(AndroidQuickLaunchOption option) onLaunch;

  final VoidCallback onCancel;

  @override
  State<AndroidLaunchDialog> createState() => _LaunchDialogState();
}

class _LaunchDialogState extends State<AndroidLaunchDialog> {
  int _selectedIndex = 0;

  List<AndroidQuickLaunchOption> get _options => [
    AndroidQuickLaunchOption.normal,
    AndroidQuickLaunchOption.coldBoot,
    AndroidQuickLaunchOption.noAudio,
    AndroidQuickLaunchOption.coldBootNoAudio,
  ];

  @override
  Component build(BuildContext context) {
    final st = SimutilTheme.of(context);
    return Center(
      child: Container(
        margin: EdgeInsets.all(16),
        decoration: st.dialogPanel('Launch: ${component.device.name}'),
        child: Padding(
          padding: EdgeInsets.all(1),
          child: Focusable(
            focused: true,
            onKeyEvent: _handleKeyEvent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._options.asMap().entries.map((entry) {
                  return _buildOption(st, entry.key, entry.value);
                }),
                SizedBox(height: 1),
                Divider(),
                Text(
                  ' Navigate: <↑/↓> | Launch: <enter> | Cancel: <esc>',
                  style: st.dimmed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Component _buildOption(
    SimutilTheme st,
    int index,
    AndroidQuickLaunchOption option,
  ) {
    final isSelected = _selectedIndex == index;
    return Row(
      children: [
        Text(isSelected ? ' ${SimutilIcons.pointer} ' : '   ', style: st.label),
        Expanded(
          child: Text(option.label, style: isSelected ? st.selected : st.body),
        ),
      ],
    );
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.escape) {
      component.onCancel();
      return true;
    }

    if (event.logicalKey == LogicalKey.enter) {
      component.onLaunch(_options[_selectedIndex]);
      return true;
    }

    if (event.logicalKey == LogicalKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1).clamp(0, _options.length - 1);
      });
      return true;
    }

    if (event.logicalKey == LogicalKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(0, _options.length - 1);
      });
      return true;
    }

    return false;
  }
}

Future<AndroidQuickLaunchOption?> showLaunchDialog({
  required BuildContext context,
  required Device device,
}) => showOverlayDialog<AndroidQuickLaunchOption>(
  context: context,
  builder: (context, completer, entry) {
    return AndroidLaunchDialog(
      device: device,
      onLaunch: (option) {
        completer.complete(option);
        entry?.remove();
      },
      onCancel: () {
        completer.complete(null);
        entry?.remove();
      },
    );
  },
);
