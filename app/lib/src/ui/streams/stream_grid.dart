import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_app/src/settings/view_settings_cubit.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_app/src/stream/streams_state.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_app/src/ui/shared/responsive.dart';
import 'package:simutil_app/src/ui/streams/stream_layout.dart';
import 'package:simutil_app/src/ui/streams/stream_tile.dart';

/// Every open stream laid out by [StreamLayout]; tiles glide to their new
/// place whenever streams open, close or the layout changes.
class StreamGrid extends StatelessWidget {
  const StreamGrid({super.key});

  static const _move = Duration(milliseconds: 320);

  @override
  Widget build(BuildContext context) {
    final settings = context.value<ViewSettingsCubit, ViewSettings>();
    return RecordableArea(
      child: BlocSignalBuilder<StreamsCubit, StreamsState>(
        builder: (context, state) {
          if (state.entries.isEmpty) return const _EmptyState();
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final ids = [for (final e in state.entries) e.device.id];
                final rects = streamRects(
                  ids,
                  constraints.biggest,
                  layout: settings.layout,
                  focusId: settings.spotlightId,
                );
                final focus =
                    settings.layout != StreamLayout.grid && ids.length > 1
                    ? spotlightFocus(ids, settings.spotlightId)
                    : null;
                return Stack(
                  children: [
                    for (final entry in state.entries)
                      AnimatedPositioned.fromRect(
                        key: ValueKey(entry.device.id),
                        rect: rects[entry.device.id]!,
                        duration: _move,
                        curve: Curves.easeInOutCubic,
                        child: _Appear(
                          child: StreamTile(
                            entry: entry,
                            mode: focus == null
                                ? StreamTileMode.grid
                                : entry.device.id == focus
                                ? StreamTileMode.spotlight
                                : StreamTileMode.thumbnail,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Fades and scales a tile in the first time it is built.
class _Appear extends StatelessWidget {
  const _Appear({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOutCubic,
    child: child,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.scale(scale: 0.94 + 0.06 * value, child: child),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: t.panel,
              borderRadius: BorderRadius.circular(SimuTokens.radiusLarge),
              border: Border.all(color: t.border),
            ),
            child: Icon(LucideIcons.monitorPlay, size: 22, color: t.textFaint),
          ),
          const SizedBox(height: 14),
          Text('No streams yet', style: t.title),
          const SizedBox(height: 6),
          Text('Start or stream a device from the sidebar.', style: t.caption),
        ],
      ),
    );
  }
}
