import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

import '../../stream/device_stream.dart';
import '../../stream/streams_cubit.dart';
import '../../stream/streams_state.dart';
import '../shared/responsive.dart';
import '../shared/touch_surface.dart';

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
    final stream = cubit.streamFor(entry.device.id);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TileHeader(
            title: entry.device.name,
            buttons: stream?.buttons ?? const [],
            onPress: (b) => stream?.press(b),
            onClose: () => cubit.closeStream(entry.device.id),
          ),
          switch (entry.status) {
            StreamLive(:final size) when stream != null => LayoutBuilder(
              builder: (context, constraints) {
                final fit = fitVideo(
                  size.width / size.height,
                  constraints.maxWidth,
                  maxVideoHeight,
                );
                return SizedBox.fromSize(
                  size: fit,
                  child: TouchSurface(stream: stream),
                );
              },
            ),
            StreamFailed(:final message) => _Placeholder(
              child: Text(message, textAlign: TextAlign.center),
            ),
            _ => const _Placeholder(child: CircularProgressIndicator()),
          },
        ],
      ),
    );
  }
}

class _TileHeader extends StatelessWidget {
  const _TileHeader({
    required this.title,
    required this.buttons,
    required this.onPress,
    required this.onClose,
  });

  final String title;
  final List<DeviceButton> buttons;
  final ValueChanged<DeviceButton> onPress;
  final VoidCallback onClose;

  static IconData _icon(DeviceButton button) => switch (button) {
    DeviceButton.back => Icons.arrow_back,
    DeviceButton.home => Icons.circle_outlined,
    DeviceButton.recents => Icons.crop_square,
    DeviceButton.lock => Icons.lock_outline,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        children: [
          Expanded(child: Text(title, overflow: TextOverflow.ellipsis)),
          for (final button in buttons)
            IconButton(
              tooltip: button.name,
              iconSize: 18,
              icon: Icon(_icon(button)),
              onPressed: () => onPress(button),
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
