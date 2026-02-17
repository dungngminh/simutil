import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/simutil_icons.dart';
import 'package:simutil/components/simutil_theme.dart';
import 'package:simutil/models/device.dart';
import 'package:simutil/models/device_type.dart';
import 'package:simutil/models/launch_options.dart';

/// A modal overlay dialog that shows launch options before starting a device.
///
/// Use [showLaunchDialog] to display this as an overlay.
class LaunchDialog extends StatefulComponent {
  final Device device;
  final LaunchOptions initialOptions;

  /// Called when user confirms launch (Enter).
  final void Function(LaunchOptions options) onLaunch;

  /// Called when user cancels (Escape).
  final VoidCallback onCancel;

  const LaunchDialog({
    super.key,
    required this.device,
    required this.initialOptions,
    required this.onLaunch,
    required this.onCancel,
  });

  @override
  State<LaunchDialog> createState() => _LaunchDialogState();
}

class _LaunchDialogState extends State<LaunchDialog> {
  late LaunchOptions _options;
  int _focusedField = 0;

  int get _fieldCount => component.device.type == DeviceType.android ? 4 : 0;

  @override
  void initState() {
    super.initState();
    _options = component.initialOptions;
  }

  @override
  Component build(BuildContext context) {
    final st = SimutilTheme.of(context);
    final isAndroid = component.device.type == DeviceType.android;

    return Stack(
      children: [
        // Semi-transparent backdrop
        Container(color: Color.fromARGB(180, 0, 0, 0)),
        // Centered dialog
        Center(
          child: Container(
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
                    Text(
                      ' ${component.device.platform}  •  ${component.device.state.label}',
                      style: st.dimmed,
                    ),
                    Divider(),
                    if (isAndroid) ...[
                      _buildToggle(st, 0, 'No Audio', _options.noAudio),
                      _buildToggle(st, 1, 'Wipe Data', _options.wipeData),
                      _buildGpuField(st, 2),
                      _buildToggle(st, 3, 'No Snapshot', _options.noSnapshot),
                    ] else
                      Text(
                        ' No additional options for iOS simulators',
                        style: st.dimmed,
                      ),
                    Divider(),
                    Text(' ⏎ Launch  Esc Cancel', style: st.dimmed),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Component _buildToggle(SimutilTheme st, int index, String label, bool value) {
    final isFocused = _focusedField == index;
    return Row(
      children: [
        Text(isFocused ? ' ${SimutilIcons.pointer} ' : '   ', style: st.label),
        SizedBox(
          width: 16,
          child: Text(label, style: isFocused ? st.bold : st.body),
        ),
        Text(
          value ? SimutilIcons.checked : SimutilIcons.unchecked,
          style: TextStyle(
            color: value ? st.success : st.outlineVariant,
            fontWeight: isFocused ? FontWeight.bold : null,
          ),
        ),
      ],
    );
  }

  Component _buildGpuField(SimutilTheme st, int index) {
    final isFocused = _focusedField == index;
    return Row(
      children: [
        Text(isFocused ? ' ${SimutilIcons.pointer} ' : '   ', style: st.label),
        SizedBox(
          width: 16,
          child: Text('GPU Mode', style: isFocused ? st.bold : st.body),
        ),
        Text(
          '${SimutilIcons.cycleLeft} ',
          style: isFocused ? st.body : st.dimmed,
        ),
        Text(
          _options.gpu,
          style: TextStyle(
            color: st.warning,
            fontWeight: isFocused ? FontWeight.bold : null,
          ),
        ),
        Text(
          ' ${SimutilIcons.cycleRight}',
          style: isFocused ? st.body : st.dimmed,
        ),
      ],
    );
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    // Escape → cancel, close overlay
    if (event.logicalKey == LogicalKey.escape) {
      component.onCancel();
      return true;
    }

    // Enter → launch with current options
    if (event.logicalKey == LogicalKey.enter) {
      component.onLaunch(_options);
      return true;
    }

    if (_fieldCount == 0) return false;

    if (event.logicalKey == LogicalKey.arrowUp) {
      setState(() {
        _focusedField = (_focusedField - 1).clamp(0, _fieldCount - 1);
      });
      return true;
    }

    if (event.logicalKey == LogicalKey.arrowDown) {
      setState(() {
        _focusedField = (_focusedField + 1).clamp(0, _fieldCount - 1);
      });
      return true;
    }

    if (event.logicalKey == LogicalKey.space ||
        event.logicalKey == LogicalKey.arrowLeft ||
        event.logicalKey == LogicalKey.arrowRight) {
      _toggleField(event.logicalKey == LogicalKey.arrowRight);
      return true;
    }

    return false;
  }

  void _toggleField(bool forward) {
    setState(() {
      switch (_focusedField) {
        case 0:
          _options = _options.copyWith(noAudio: !_options.noAudio);
          break;
        case 1:
          _options = _options.copyWith(wipeData: !_options.wipeData);
          break;
        case 2:
          final modes = ['auto', 'host', 'swiftshader_indirect', 'off'];
          final idx = modes.indexOf(_options.gpu);
          final next = forward
              ? (idx + 1) % modes.length
              : (idx - 1 + modes.length) % modes.length;
          _options = _options.copyWith(gpu: modes[next]);
          break;
        case 3:
          _options = _options.copyWith(noSnapshot: !_options.noSnapshot);
          break;
      }
    });
  }
}

/// Show the [LaunchDialog] as a modal overlay.
///
/// Returns the chosen [LaunchOptions], or `null` if cancelled.
Future<LaunchOptions?> showLaunchDialog(
  BuildContext context, {
  required Device device,
  required LaunchOptions initialOptions,
}) {
  final completer = Completer<LaunchOptions?>();
  late final OverlayEntry entry;

  entry = OverlayEntry(
    opaque: true,
    builder: (context) {
      return LaunchDialog(
        device: device,
        initialOptions: initialOptions,
        onLaunch: (options) {
          entry.remove();
          completer.complete(options);
        },
        onCancel: () {
          entry.remove();
          completer.complete(null);
        },
      );
    },
  );

  Overlay.of(context).insert(entry);
  return completer.future;
}
