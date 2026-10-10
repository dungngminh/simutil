import 'dart:io';

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_app/src/devices/slim_mode_cubit.dart';
import 'package:simutil_app/src/di.dart';
import 'package:simutil_app/src/mcp/mcp_server.dart';
import 'package:simutil_app/src/recording/grid_record_quality.dart';
import 'package:simutil_app/src/recording/grid_recorder.dart';
import 'package:simutil_app/src/settings/recordings_dir.dart';
import 'package:simutil_app/src/settings/view_settings_cubit.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_app/src/stream/streams_state.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_app/src/ui/mcp_connect_dialog.dart';
import 'package:simutil_app/src/ui/recording_toast.dart';
import 'package:simutil_apple/simutil_apple.dart';
import 'package:window_manager/window_manager.dart';

/// Window-draggable bar over the grid: sidebar toggle on the left, one
/// toolbar on the right (grid recording, layouts, Xcode cleanup, MCP).
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.sidebarOpen,
    required this.onToggleSidebar,
  });

  final bool sidebarOpen;
  final VoidCallback onToggleSidebar;

  @override
  Widget build(BuildContext context) {
    final streams = context.value<StreamsCubit, StreamsState>().entries;
    return DragToMoveArea(
      child: Container(
        height: 52,
        // Leave room for the macOS traffic lights when the sidebar is hidden.
        padding: EdgeInsets.only(
          left: !sidebarOpen && Platform.isMacOS ? 78 : 10,
          right: 16,
        ),
        child: Row(
          children: [
            SimuIconButton(
              icon: sidebarOpen
                  ? LucideIcons.panelLeftClose
                  : LucideIcons.panelLeft,
              tooltip: sidebarOpen ? 'Hide devices' : 'Show devices',
              onPressed: onToggleSidebar,
            ),
            const Spacer(),
            SimuToolbar(
              children: [
                _ViewActions(
                  hasStreams: streams.isNotEmpty,
                  deviceRecording: streams.any((e) => e.recording),
                ),
                const SimuToolbarDivider(),
                const _CornerActions(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Xcode DerivedData cleanup (macOS) and the MCP connect guide.
class _CornerActions extends StatelessWidget {
  const _CornerActions();

  @override
  Widget build(BuildContext context) {
    final mcp = getIt<McpServer>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (Platform.isMacOS) const _SlimModeButton(),
        if (Platform.isMacOS)
          SimuIconButton(
            icon: LucideIcons.hammer,
            tooltip: 'Clear Xcode DerivedData',
            onPressed: () => _clearDerivedData(context),
          ),
        SimuIconButton(
          icon: LucideIcons.plug,
          tooltip: 'Connect an agent (MCP)',
          color: mcp.running ? null : SimuTokens.of(context).danger,
          onPressed: () =>
              showMcpConnectDialog(context, url: mcp.url, running: mcp.running),
        ),
      ],
    );
  }

  Future<void> _clearDerivedData(BuildContext context) async {
    final service = getIt<XcodeCacheService>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _ConfirmClearDialog(path: service.derivedDataPath ?? 'DerivedData'),
    );
    if (ok != true) return;
    final result = await service.clearDerivedData();
    if (!context.mounted) return;
    showNotice(
      context,
      result.success ? 'DerivedData cleared' : 'Clear DerivedData failed',
      subtitle: result.message,
      tone: result.success ? NoticeTone.success : NoticeTone.error,
    );
  }
}

class _ConfirmClearDialog extends StatelessWidget {
  const _ConfirmClearDialog({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return AlertDialog(
      backgroundColor: t.panel,
      title: Text('Clear Xcode DerivedData?', style: t.title),
      content: Text(
        'Deletes everything in $path. Xcode rebuilds it on the next build; '
        'close Xcode first for the cleanest result.',
        style: t.body,
      ),
      actions: [
        SimuButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        SimuButton(
          label: 'Clear',
          primary: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

/// Grid recording and the layout switch.
class _ViewActions extends StatelessWidget {
  const _ViewActions({required this.hasStreams, required this.deviceRecording});

  final bool hasStreams;

  /// A device is recording: only one recording runs at a time, so the grid
  /// recording controls are hidden.
  final bool deviceRecording;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final layout = context.select<ViewSettingsCubit, StreamLayout>(
      (c) => c.stateValue.layout,
    );
    final cubit = context.read<ViewSettingsCubit>();
    final recordingGrid = context.value<GridRecorderCubit, bool>();
    final quality = context.select<ViewSettingsCubit, GridRecordQuality>(
      (c) => c.stateValue.gridQuality,
    );
    SimuIconButton layoutButton(
      StreamLayout value,
      IconData icon,
      String tip,
    ) => SimuIconButton(
      icon: icon,
      tooltip: tip,
      active: layout == value,
      onPressed: () => cubit.setLayout(value),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (recordingGrid || !deviceRecording) ...[
          SimuIconButton(
            icon: recordingGrid ? LucideIcons.circleStop : LucideIcons.video,
            tooltip: recordingGrid
                ? 'Stop recording grid'
                : 'Record grid (${quality.summary})',
            color: recordingGrid ? t.danger : null,
            onPressed: recordingGrid || hasStreams
                ? () => _toggleGridRecording(context)
                : () => showNotice(
                    context,
                    'Nothing to record yet',
                    subtitle: 'Stream a device first.',
                  ),
          ),
          _GridQualityButton(quality: quality, enabled: !recordingGrid),
          const SimuToolbarDivider(),
        ],
        layoutButton(StreamLayout.grid, LucideIcons.layoutGrid, 'Grid'),
        layoutButton(
          StreamLayout.spotlightVertical,
          LucideIcons.panelRight,
          'Spotlight: one large, the rest on the right',
        ),
        layoutButton(
          StreamLayout.spotlightHorizontal,
          LucideIcons.panelBottom,
          'Spotlight: one large, the rest along the bottom',
        ),
      ],
    );
  }

  Future<void> _toggleGridRecording(BuildContext context) async {
    final recorder = context.read<GridRecorderCubit>();
    try {
      if (recorder.isRecording) {
        await recorder.stop();
      } else {
        final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
        await recorder.start(
          '${recordingsDirectory()}/simutil-grid-$stamp.mp4',
          quality: context.read<ViewSettingsCubit>().stateValue.gridQuality,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      showNotice(
        context,
        'Grid recording failed',
        subtitle: '$e',
        tone: NoticeTone.error,
      );
    }
  }
}

/// The grid recording preset next to the record button; opens a native
/// menu to change it (not while recording).
class _GridQualityButton extends StatelessWidget {
  const _GridQualityButton({required this.quality, required this.enabled});

  final GridRecordQuality quality;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final cubit = context.read<ViewSettingsCubit>();
    return MenuAnchor(
      menuChildren: [
        for (final option in GridRecordQuality.values)
          MenuItemButton(
            leadingIcon: Icon(
              option == quality ? LucideIcons.check : null,
              size: 14,
              color: t.accent,
            ),
            onPressed: () => cubit.setGridQuality(option),
            child: Text(
              '${option.summary} · ${option.bitRateMbps} Mbps',
              style: t.caption.copyWith(color: t.text),
            ),
          ),
      ],
      builder: (context, controller, _) => _chip(
        context,
        onTap: enabled
            ? () => controller.isOpen ? controller.close() : controller.open()
            : null,
      ),
    );
  }

  Widget _chip(BuildContext context, {required VoidCallback? onTap}) {
    final t = SimuTokens.of(context);
    return Tooltip(
      message: enabled
          ? 'Grid recording quality: ${quality.summary} · '
                '${quality.bitRateMbps} Mbps'
          : 'Recording at ${quality.summary}',
      child: SimuHoverable(
        onTap: onTap,
        builder: (context, hovered) => AnimatedContainer(
          duration: SimuTokens.motion,
          height: 28,
          padding: const EdgeInsets.only(left: 4, right: 6),
          decoration: BoxDecoration(
            color: hovered && enabled ? t.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                quality.summary,
                style: t.mono.copyWith(
                  color: hovered && enabled ? t.text : t.textMuted,
                ),
              ),
              if (enabled) ...[
                const SizedBox(width: 3),
                Icon(LucideIcons.chevronDown, size: 12, color: t.textFaint),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Slim / default mode for simulators; spins while open simulators reboot.
class _SlimModeButton extends StatelessWidget {
  const _SlimModeButton();

  @override
  Widget build(BuildContext context) {
    final state = context.value<SlimModeCubit, SlimModeState>();
    if (state.applying) {
      return const Padding(padding: EdgeInsets.all(7), child: SimuSpinner());
    }
    return SimuIconButton(
      icon: LucideIcons.leaf,
      active: state.enabled,
      tooltip: state.enabled
          ? 'Slim mode: simulators run without background services. '
                'Click for default (reboots open ones)'
          : 'Default mode. Click to run simulators slim (reboots open ones)',
      onPressed: () =>
          context.read<SlimModeCubit>().setMode(enabled: !state.enabled),
    );
  }
}
