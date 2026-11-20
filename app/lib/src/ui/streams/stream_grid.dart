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
/// place whenever streams open, close or the layout changes, and the grid
/// scrolls once tiles would get too small to use.
///
/// In the grid layout a tile is reordered like a reorderable list:
/// long-press its header and it follows the pointer while the others slide
/// out of the way; it settles into the slot it was dropped on.
class StreamGrid extends StatefulWidget {
  const StreamGrid({super.key});

  @override
  State<StreamGrid> createState() => _StreamGridState();
}

class _StreamGridState extends State<StreamGrid> {
  static const _move = Duration(milliseconds: 320);

  final _stackKey = GlobalKey();

  /// The dragged stream, the slot it would drop into, where the pointer
  /// grabbed it (from the tile's top-left) and the pointer, both in the
  /// grid's coordinates.
  String? _dragId;
  int _dragIndex = 0;
  Offset _grab = Offset.zero;
  Offset _pointer = Offset.zero;

  /// Slot rects of the last layout, by position.
  List<Rect> _slots = const [];

  Offset _local(Offset global) {
    final box = _stackKey.currentContext?.findRenderObject();
    return box is RenderBox ? box.globalToLocal(global) : global;
  }

  TileDrag _dragFor(String id, List<String> ids) => TileDrag(
    start: (global) {
      final index = ids.indexOf(id);
      if (index < 0 || index >= _slots.length) return;
      final local = _local(global);
      setState(() {
        _dragId = id;
        _dragIndex = index;
        _pointer = local;
        _grab = local - _slots[index].topLeft;
      });
    },
    update: (global) {
      if (_dragId == null) return;
      final pointer = _local(global);
      // The slot under the dragged tile's center; slots do not move while
      // dragging, so the order cannot flip back and forth.
      final center =
          pointer - _grab + _slots[_dragIndex].size.center(Offset.zero);
      final over = _slots.indexWhere((r) => r.contains(center));
      setState(() {
        _pointer = pointer;
        if (over >= 0) _dragIndex = over;
      });
    },
    end: () {
      final id = _dragId;
      if (id == null) return;
      context.read<StreamsCubit>().moveStream(id, _dragIndex);
      setState(() => _dragId = null);
    },
  );

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
                final grid = settings.layout == StreamLayout.grid;
                final dragId = grid && ids.length > 1 && ids.contains(_dragId)
                    ? _dragId
                    : null;
                // A stream closed mid-drag: the dragged one (its gesture
                // never ends) or another (the drop slot may be gone).
                if (dragId == null) _dragId = null;
                _dragIndex = _dragIndex.clamp(0, ids.length - 1);
                // While dragging, lay out the order it would drop into.
                final order = [...ids];
                if (dragId != null) {
                  order
                    ..remove(dragId)
                    ..insert(_dragIndex, dragId);
                }
                final rects = streamRects(
                  order,
                  constraints.biggest,
                  layout: settings.layout,
                  focusId: settings.spotlightId,
                );
                _slots = [for (final id in order) rects[id]!];
                final focus = !grid && ids.length > 1
                    ? spotlightFocus(ids, settings.spotlightId)
                    : null;
                // Taller than the view when the grid outgrew it: scroll.
                final height = rects.values.fold(
                  constraints.maxHeight,
                  (h, r) => r.bottom > h ? r.bottom : h,
                );
                // The dragged tile last, so it is drawn on top.
                final entries = [
                  for (final e in state.entries)
                    if (e.device.id != dragId) e,
                  for (final e in state.entries)
                    if (e.device.id == dragId) e,
                ];
                final stack = Stack(
                  key: _stackKey,
                  children: [
                    for (final entry in entries)
                      AnimatedPositioned.fromRect(
                        key: ValueKey(entry.device.id),
                        rect: entry.device.id == dragId
                            ? (_pointer - _grab) & rects[dragId]!.size
                            : rects[entry.device.id]!,
                        duration: entry.device.id == dragId
                            ? Duration.zero
                            : _move,
                        curve: Curves.easeInOutCubic,
                        child: _Appear(
                          child: StreamTile(
                            entry: entry,
                            mode: focus == null
                                ? StreamTileMode.grid
                                : entry.device.id == focus
                                ? StreamTileMode.spotlight
                                : StreamTileMode.thumbnail,
                            drag: grid && ids.length > 1
                                ? _dragFor(entry.device.id, ids)
                                : null,
                            lifted: entry.device.id == dragId,
                          ),
                        ),
                      ),
                  ],
                );
                if (height <= constraints.maxHeight) return stack;
                return SingleChildScrollView(
                  child: SizedBox(height: height, child: stack),
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
