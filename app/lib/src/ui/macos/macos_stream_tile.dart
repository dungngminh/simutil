import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../stream/device_stream.dart';
import '../../stream/streams_cubit.dart';
import '../../stream/streams_state.dart';
import '../shared/responsive.dart';
import '../shared/touch_surface.dart';

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
    final stream = cubit.streamFor(entry.device.id);
    final theme = MacosTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.canvasColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
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
                builder: (context, constraints) => SizedBox.fromSize(
                  size: fitVideo(
                    size.width / size.height,
                    constraints.maxWidth,
                    maxVideoHeight,
                  ),
                  child: TouchSurface(stream: stream),
                ),
              ),
              StreamFailed(:final message) => _Placeholder(
                child: Text(message, textAlign: TextAlign.center),
              ),
              _ => const _Placeholder(child: ProgressCircle()),
            },
          ],
        ),
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
    DeviceButton.back => CupertinoIcons.back,
    DeviceButton.home => CupertinoIcons.circle,
    DeviceButton.recents => CupertinoIcons.square_stack,
    DeviceButton.lock => CupertinoIcons.lock,
  };

  Widget _button(IconData icon, String label, VoidCallback onPressed) =>
      MacosTooltip(
        message: label,
        child: MacosIconButton(
          icon: MacosIcon(icon, size: 15),
          semanticLabel: label,
          onPressed: onPressed,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: MacosTheme.of(context).typography.headline,
              ),
            ),
            for (final button in buttons)
              _button(_icon(button), button.name, () => onPress(button)),
            _button(CupertinoIcons.xmark, 'Close', onClose),
          ],
        ),
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
