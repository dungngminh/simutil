import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:simutil_core/simutil_core.dart';

import '../../settings/recordings_dir.dart';
import '../../settings/view_settings_cubit.dart';
import '../../stream/streams_cubit.dart';
import '../../stream/streams_state.dart';
import '../shared/device_context_menu.dart';
import '../shared/stream_tile_body.dart';

/// One device: title bar with buttons, then the live screen.
class MaterialStreamTile extends StatelessWidget {
  const MaterialStreamTile({
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onSecondaryTap: () => showDeviceContextMenu(context, entry.device),
            child: _TileHeader(
              entry: entry,
              buttons: session?.buttons ?? const [],
              onPress: (b) => session?.press(b),
              onRecord: () =>
                  cubit.toggleRecording(entry.device.id, recordingsDirectory()),
              onClose: () => cubit.closeStream(entry.device.id),
            ),
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
                _ => const CircularProgressIndicator(),
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
    DeviceButton.back => Icons.arrow_back,
    DeviceButton.home => Icons.circle_outlined,
    DeviceButton.recents => Icons.crop_square,
    DeviceButton.lock => Icons.lock_outline,
  };

  @override
  Widget build(BuildContext context) {
    final live = entry.status is SessionLive;
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(entry.device.name, overflow: TextOverflow.ellipsis),
          ),
          for (final button in buttons)
            IconButton(
              tooltip: button.name,
              iconSize: 18,
              icon: Icon(_icon(button)),
              onPressed: live ? () => onPress(button) : null,
            ),
          IconButton(
            tooltip: entry.recording ? 'Stop recording' : 'Record',
            iconSize: 18,
            icon: Icon(
              entry.recording ? Icons.stop_circle : Icons.fiber_manual_record,
              color: entry.recording ? Colors.red : null,
            ),
            onPressed: live ? onRecord : null,
          ),
          IconButton(
            tooltip: 'Close',
            iconSize: 18,
            icon: const Icon(Icons.close),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _InputBlockedBanner extends StatelessWidget {
  const _InputBlockedBanner({required this.onRepair});

  final Future<void> Function() onRepair;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      content: const Text(
        'Xcode Device Hub took over input. Repair restarts the apps on this simulator.',
      ),
      actions: [
        TextButton(onPressed: onRepair, child: const Text('Repair input')),
      ],
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
