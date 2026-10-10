import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:simutil_core/simutil_core.dart';

import '../../settings/recordings_dir.dart';
import '../../settings/view_settings_cubit.dart';
import '../../stream/streams_cubit.dart';
import '../../stream/streams_state.dart';
import '../shared/stream_tile_body.dart';

/// One device: title row with buttons, then the live screen.
class MacosStreamTile extends StatelessWidget {
  const MacosStreamTile({
    super.key,
    required this.entry,
    required this.maxVideoHeight,
  });

  final StreamEntry entry;
  final double maxVideoHeight;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StreamsCubit>();
    final session = cubit.sessionFor(entry.device.id);
    final showFrame = context.select<ViewSettingsCubit, bool>(
      (c) => c.stateValue.showFrames,
    );
    final theme = MacosTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.canvasColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TileHeader(
            entry: entry,
            buttons: session?.buttons ?? const [],
            onPress: (b) => session?.press(b),
            onRecord: () =>
                cubit.toggleRecording(entry.device.id, recordingsDirectory()),
            onClose: () => cubit.closeStream(entry.device.id),
          ),
          StreamTileBody(
            entry: entry,
            session: session,
            maxVideoHeight: maxVideoHeight,
            showFrame: showFrame,
            banner: (s) => _InputBlockedBanner(onRepair: s.repairInput),
            placeholder: (status) => _Placeholder(
              child: switch (status) {
                SessionFailed(:final message) => Text(
                  message,
                  textAlign: TextAlign.center,
                ),
                _ => const ProgressCircle(),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TileHeader extends StatelessWidget {
  const _TileHeader({
    required this.entry,
    required this.buttons,
    required this.onPress,
    required this.onRecord,
    required this.onClose,
  });

  final StreamEntry entry;
  final List<DeviceButton> buttons;
  final ValueChanged<DeviceButton> onPress;
  final VoidCallback onRecord;
  final VoidCallback onClose;

  static IconData _icon(DeviceButton button) => switch (button) {
    DeviceButton.back => CupertinoIcons.back,
    DeviceButton.home => CupertinoIcons.circle,
    DeviceButton.recents => CupertinoIcons.square_stack,
    DeviceButton.lock => CupertinoIcons.lock,
  };

  Widget _button(
    IconData icon,
    String label,
    VoidCallback? onPressed, {
    Color? color,
  }) => MacosTooltip(
    message: label,
    child: MacosIconButton(
      icon: MacosIcon(icon, size: 15, color: color),
      semanticLabel: label,
      onPressed: onPressed,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final live = entry.status is SessionLive;
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.device.name,
                overflow: TextOverflow.ellipsis,
                style: MacosTheme.of(context).typography.headline,
              ),
            ),
            for (final button in buttons)
              _button(
                _icon(button),
                button.name,
                live ? () => onPress(button) : null,
              ),
            _button(
              entry.recording
                  ? CupertinoIcons.stop_circle_fill
                  : CupertinoIcons.recordingtape,
              entry.recording ? 'Stop recording' : 'Record',
              live ? onRecord : null,
              color: entry.recording ? MacosColors.systemRedColor : null,
            ),
            _button(CupertinoIcons.xmark, 'Close', onClose),
          ],
        ),
      ),
    );
  }
}

class _InputBlockedBanner extends StatelessWidget {
  const _InputBlockedBanner({required this.onRepair});

  final Future<void> Function() onRepair;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          const MacosIcon(
            CupertinoIcons.exclamationmark_triangle,
            color: MacosColors.systemOrangeColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Xcode Device Hub took over input. Repair restarts the apps on this simulator.',
            ),
          ),
          PushButton(
            controlSize: ControlSize.small,
            onPressed: onRepair,
            child: const Text('Repair input'),
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Center(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}
