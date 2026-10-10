import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

import '../stream/device_stream.dart';
import '../stream/streams_cubit.dart';
import '../stream/streams_state.dart';

/// One device: title bar with buttons, then the live screen.
class StreamTile extends StatelessWidget {
  const StreamTile({super.key, required this.entry});

  final StreamEntry entry;

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
            StreamLive(:final size) when stream != null => AspectRatio(
              aspectRatio: size.width / size.height,
              child: _TouchSurface(stream: stream),
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

/// Video plus pointer input, normalized to the video's own bounds.
class _TouchSurface extends StatelessWidget {
  const _TouchSurface({required this.stream});

  final DeviceStream stream;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        Offset norm(Offset p) =>
            Offset(p.dx / constraints.maxWidth, p.dy / constraints.maxHeight);
        return Listener(
          onPointerDown: (e) =>
              stream.touch(TouchPhase.down, norm(e.localPosition)),
          onPointerMove: (e) =>
              stream.touch(TouchPhase.move, norm(e.localPosition)),
          onPointerUp: (e) =>
              stream.touch(TouchPhase.up, norm(e.localPosition)),
          child: stream.buildView(),
        );
      },
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
