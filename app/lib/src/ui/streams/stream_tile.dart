import 'dart:math';

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_app/src/recording/grid_recorder.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_app/src/settings/device_settings_cubit.dart';
import 'package:simutil_app/src/settings/recordings_dir.dart';
import 'package:simutil_app/src/settings/view_settings_cubit.dart';
import 'package:simutil_app/src/stream/stream_fps.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_app/src/stream/streams_state.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_app/src/ui/shared/device_context_menu.dart';
import 'package:simutil_app/src/ui/shared/stream_tile_body.dart';
import 'package:simutil_core/simutil_core.dart';

/// Where a tile sits in the layout.
enum StreamTileMode {
  grid,

  /// The large stream of a spotlight layout.
  spotlight,

  /// A small tile in the spotlight strip; clicking it swaps it in.
  thumbnail,
}

/// One device: header with status and controls, then the live screen
/// filling the rest of the tile.
class StreamTile extends StatelessWidget {
  const StreamTile({super.key, required this.entry, required this.mode});

  final StreamEntry entry;
  final StreamTileMode mode;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final session = context.read<StreamsCubit>().sessionFor(entry.device.id);
    final view = context.read<ViewSettingsCubit>();
    final showFrame = context.select<DeviceSettingsCubit, bool>(
      (c) => c.of(entry.device).showFrame,
    );
    // One recording at a time: hide Record while the grid or another
    // device records.
    final otherRecording =
        context.value<GridRecorderCubit, bool>() ||
        context.select<StreamsCubit, bool>(
          (c) => c.stateValue.entries.any(
            (e) => e.recording && e.device.id != entry.device.id,
          ),
        );
    final thumbnail = mode == StreamTileMode.thumbnail;
    // The tree keeps the same shape in every mode and size so the video (and
    // its decoder) survives layout switches.
    return SimuHoverable(
      onTap: thumbnail ? () => view.spotlight(entry.device.id) : null,
      builder: (context, hovered) => AnimatedContainer(
        duration: SimuTokens.motion,
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: thumbnail && hovered ? t.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(SimuTokens.radiusLarge + 1.5),
        ),
        child: SimuPanel(
          child: _MinSize(
            minWidth: 80,
            minHeight: 72,
            child: Column(
              children: [
                GestureDetector(
                  onSecondaryTap: () =>
                      showDeviceContextMenu(context, entry.device),
                  child: thumbnail
                      ? _ThumbnailHeader(entry: entry)
                      : StreamTileHeader(
                          entry: entry,
                          session: session,
                          showResolution: mode == StreamTileMode.spotlight,
                          actions: _tileActions(
                            context,
                            entry,
                            session,
                            mode,
                            showFrame,
                            canRecord: !otherRecording,
                          ),
                        ),
                ),
                Expanded(
                  child: _TileBody(
                    entry: entry,
                    session: session,
                    showFrame: showFrame,
                    compact: thumbnail,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays [child] out at least [minWidth] x [minHeight] and scales it down to
/// fit smaller boxes, so nothing overflows mid-animation. Always the same
/// widgets, so children keep their state across sizes.
class _MinSize extends StatelessWidget {
  const _MinSize({
    required this.minWidth,
    required this.minHeight,
    required this.child,
  });

  final double minWidth;
  final double minHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => FittedBox(
      child: SizedBox(
        width: max(box.maxWidth, minWidth),
        height: max(box.maxHeight, minHeight),
        child: child,
      ),
    ),
  );
}

class _TileBody extends StatelessWidget {
  const _TileBody({
    required this.entry,
    required this.session,
    required this.showFrame,
    required this.compact,
  });

  final StreamEntry entry;
  final DeviceSession? session;
  final bool showFrame;
  final bool compact;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: compact,
    child: _MinSize(
      minWidth: 200,
      minHeight: 160,
      child: LayoutBuilder(
        builder: (context, box) => Center(
          child: StreamTileBody(
            entry: entry,
            session: session,
            maxVideoHeight: box.maxHeight - 16,
            showFrame: showFrame,
            banner: (s) => _InputBlockedBanner(onRepair: s.repairInput),
            placeholder: (status) =>
                _Placeholder(status: status, compact: compact),
          ),
        ),
      ),
    ),
  );
}

/// A header control; the header keeps the highest [priority] ones that fit
/// and moves the rest into a "more" menu.
class TileAction {
  const TileAction({
    required this.icon,
    required this.label,
    required this.priority,
    this.onPressed,
    this.active = false,
    this.color,
    this.nav = false,
  });

  final IconData icon;
  final String label;
  final int priority;
  final VoidCallback? onPressed;
  final bool active;
  final Color? color;

  /// A device button (back, home…); a divider separates these from the rest.
  final bool nav;
}

List<TileAction> _tileActions(
  BuildContext context,
  StreamEntry entry,
  DeviceSession? session,
  StreamTileMode mode,
  bool showFrame, {
  required bool canRecord,
}) {
  final t = SimuTokens.of(context);
  final device = entry.device;
  final streams = context.read<StreamsCubit>();
  final view = context.read<ViewSettingsCubit>();
  final live = entry.status is SessionLive;
  return [
    for (final button in session?.buttons ?? const <DeviceButton>[])
      TileAction(
        icon: _buttonIcon(button),
        label: _buttonLabel(button),
        priority: 1,
        nav: true,
        onPressed: live ? () => session!.press(button) : null,
      ),
    TileAction(
      icon: showFrame ? LucideIcons.smartphone : LucideIcons.squareDashed,
      label: showFrame ? 'Hide device frame' : 'Show device frame',
      priority: 2,
      active: showFrame,
      onPressed: () => context.read<DeviceSettingsCubit>().update(
        device,
        (s) => s.copyWith(showFrame: !s.showFrame),
      ),
    ),
    if (entry.recording || canRecord)
      TileAction(
        icon: entry.recording ? LucideIcons.circleStop : LucideIcons.video,
        label: entry.recording ? 'Stop recording' : 'Record screen',
        priority: 5,
        color: entry.recording ? t.danger : null,
        onPressed: live
            ? () => streams.toggleRecording(device.id, recordingsDirectory())
            : null,
      ),
    if (!device.type.isPhysical)
      TileAction(
        icon: LucideIcons.power,
        label: 'Shut down device',
        priority: 3,
        onPressed: () async {
          final devices = context.read<DevicesCubit>();
          await streams.closeStream(device.id);
          await devices.shutdown(device);
        },
      ),
    if (mode == StreamTileMode.grid)
      TileAction(
        icon: LucideIcons.maximize2,
        label: 'Show large (spotlight)',
        priority: 6,
        onPressed: () => view.spotlight(device.id),
      )
    else
      TileAction(
        icon: LucideIcons.minimize2,
        label: 'Back to grid',
        priority: 6,
        onPressed: () => view.setLayout(StreamLayout.grid),
      ),
    TileAction(
      icon: LucideIcons.x,
      label: 'Close stream',
      priority: 7,
      onPressed: () => streams.closeStream(device.id),
    ),
  ];
}

String _buttonLabel(DeviceButton button) => switch (button) {
  DeviceButton.back => 'Back',
  DeviceButton.home => 'Home',
  DeviceButton.recents => 'Recent apps',
  DeviceButton.lock => 'Lock screen',
};

IconData _buttonIcon(DeviceButton button) => switch (button) {
  DeviceButton.back => LucideIcons.arrowLeft,
  DeviceButton.home => LucideIcons.circle,
  DeviceButton.recents => LucideIcons.galleryHorizontalEnd,
  DeviceButton.lock => LucideIcons.lock,
};

Color _statusColor(SimuTokens t, SessionStatus status) => switch (status) {
  SessionLive() => t.success,
  SessionFailed() => t.danger,
  _ => t.warning,
};

class _ThumbnailHeader extends StatelessWidget {
  const _ThumbnailHeader({required this.entry});

  final StreamEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          SimuStatusDot(color: _statusColor(t, entry.status), size: 6),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              entry.device.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.label.copyWith(fontSize: 12),
            ),
          ),
          if (entry.recording) SimuStatusDot(color: t.danger, size: 6),
        ],
      ),
    );
  }
}

/// Status, name and the [actions] that fit the width; the rest go into a
/// "more" menu.
class StreamTileHeader extends StatelessWidget {
  const StreamTileHeader({
    super.key,
    required this.entry,
    required this.session,
    required this.actions,
    this.showResolution = false,
  });

  final StreamEntry entry;
  final DeviceSession? session;
  final List<TileAction> actions;
  final bool showResolution;

  static const _buttonWidth = 27.0; // SimuIconButton: 15 icon + 2 * 6
  static const _dividerWidth = 9.0;
  static const _dotWidth = 16.0; // status dot and its gap
  static const _minNameWidth = 56.0;

  /// The actions to show inline: the highest priorities that fit [budget]
  /// with room for the "more" button when some are left out.
  static List<TileAction> fit(List<TileAction> actions, double budget) {
    final ranked = [...actions]
      ..sort((a, b) => b.priority.compareTo(a.priority));
    for (var k = ranked.length; k > 0; k--) {
      final kept = ranked.take(k).toSet();
      final divider = kept.any((a) => a.nav) && kept.any((a) => !a.nav);
      final width =
          (k + (k < ranked.length ? 1 : 0)) * _buttonWidth +
          (divider ? _dividerWidth : 0);
      if (width <= budget) return [...actions.where(kept.contains)];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final kept = fit(actions, box.maxWidth - _dotWidth - _minNameWidth);
          final hidden = [...actions.where((a) => !kept.contains(a))];
          return Row(
            children: [
              SimuStatusDot(color: _statusColor(t, entry.status)),
              const SizedBox(width: 9),
              Expanded(
                child: _TitleLine(
                  entry: entry,
                  session: session,
                  showResolution: showResolution,
                ),
              ),
              for (final (i, action) in kept.indexed) ...[
                if (i > 0 && kept[i - 1].nav && !action.nav)
                  const SimuToolbarDivider(),
                _ActionButton(action: action),
              ],
              if (hidden.isNotEmpty && kept.isNotEmpty)
                _MoreButton(actions: hidden),
            ],
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final TileAction action;

  @override
  Widget build(BuildContext context) => SimuIconButton(
    icon: action.icon,
    tooltip: action.label,
    size: 15,
    active: action.active,
    color: action.color,
    onPressed: action.onPressed,
  );
}

/// Overflow menu for the header actions that did not fit.
class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.actions});

  final List<TileAction> actions;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return MenuAnchor(
      menuChildren: [
        for (final action in actions)
          MenuItemButton(
            leadingIcon: Icon(
              action.icon,
              size: 15,
              color: action.color ?? (action.active ? t.accent : null),
            ),
            onPressed: action.onPressed,
            child: Text(action.label, style: t.caption.copyWith(color: t.text)),
          ),
      ],
      builder: (context, controller, _) => SimuIconButton(
        icon: LucideIcons.ellipsis,
        tooltip: 'More actions',
        size: 15,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// Device name, then REC / resolution / live FPS; one line that cuts the
/// details before the name.
class _TitleLine extends StatelessWidget {
  const _TitleLine({
    required this.entry,
    required this.session,
    required this.showResolution,
  });

  final StreamEntry entry;
  final DeviceSession? session;
  final bool showResolution;

  @override
  Widget build(BuildContext context) {
    final session = this.session;
    if (session == null) return _text(context, 0);
    return ValueListenableBuilder<double>(
      valueListenable: streamFps(session),
      builder: (context, fps, _) => _text(context, fps),
    );
  }

  Widget _text(BuildContext context, double fps) {
    final t = SimuTokens.of(context);
    final status = entry.status;
    final faint = t.mono.copyWith(color: t.textFaint);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: entry.device.name, style: t.label),
          if (entry.recording) ...[
            const TextSpan(text: '  '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: SimuStatusPill(label: 'REC', color: t.danger),
            ),
          ] else if (status case SessionLive(
            :final width,
            :final height,
          ) when showResolution)
            TextSpan(text: '  $width×$height', style: faint),
          if (fps > 0)
            TextSpan(
              text: '  ${fps.round()} fps',
              style: status is SessionLive && fps < 20
                  ? faint.copyWith(color: t.warning)
                  : faint,
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }
}

class _InputBlockedBanner extends StatelessWidget {
  const _InputBlockedBanner({required this.onRepair});

  final Future<void> Function() onRepair;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: t.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(SimuTokens.radius),
        border: Border.all(color: t.warning.withValues(alpha: 0.25)),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final roomy = box.maxWidth >= 260;
          return Row(
            children: [
              Icon(LucideIcons.triangleAlert, size: 15, color: t.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message:
                      'Xcode Device Hub took over input. Repair restarts the '
                      'apps on this simulator.',
                  child: Text(
                    roomy ? 'Xcode Device Hub took over input' : 'No input',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption,
                  ),
                ),
              ),
              if (roomy) ...[
                const SizedBox(width: 8),
                SimuButton(label: 'Repair input', onPressed: onRepair),
              ] else
                SimuIconButton(
                  icon: LucideIcons.wrench,
                  tooltip: 'Repair input',
                  size: 14,
                  onPressed: onRepair,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.status, required this.compact});

  final SessionStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (status) {
          SessionFailed(:final message) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.triangleAlert, size: 20, color: t.danger),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                maxLines: compact ? 2 : 4,
                overflow: TextOverflow.ellipsis,
                style: t.caption,
              ),
            ],
          ),
          _ => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SimuSpinner(),
              if (!compact) ...[
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'connecting…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.mono,
                  ),
                ),
              ],
            ],
          ),
        },
      ),
    );
  }
}
