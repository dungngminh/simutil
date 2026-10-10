import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_app/src/devices/device_form_factor.dart';
import 'package:simutil_app/src/devices/devices_state.dart';
import 'package:simutil_app/src/settings/view_settings_cubit.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_app/src/ui/shared/device_actions.dart';
import 'package:simutil_app/src/ui/shared/device_context_menu.dart';
import 'package:simutil_core/simutil_core.dart';

/// Glyph, name, state and quick actions for one device.
class DeviceRow extends StatelessWidget {
  const DeviceRow({super.key, required this.device, required this.state});

  final Device device;
  final DevicesState state;

  static IconData _actionIcon(DeviceActionKind kind) => switch (kind) {
    DeviceActionKind.start => LucideIcons.play,
    DeviceActionKind.stop => LucideIcons.power,
    DeviceActionKind.stream => LucideIcons.monitorPlay,
  };

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final busy = state.busy.contains(device.id);
    final slim = state.slimmed.contains(device.id);
    final open = context.select<StreamsCubit, bool>(
      (c) => c.stateValue.isOpen(device.id),
    );
    final subtitle = [
      device.state.label.toLowerCase(),
      if (slim) 'slim',
      if (open) 'streaming',
    ].join(' · ');
    return SimuHoverable(
      // Tapping an open device brings its stream into the spotlight.
      onTap: open
          ? () => context.read<ViewSettingsCubit>().spotlight(device.id)
          : null,
      onSecondaryTap: () => showDeviceContextMenu(context, device),
      builder: (context, hovered) => AnimatedContainer(
        duration: SimuTokens.motion,
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.fromLTRB(6, 6, 4, 6),
        decoration: BoxDecoration(
          color: open
              ? t.accent.withValues(alpha: hovered ? 0.14 : 0.08)
              : hovered
              ? t.hover
              : Colors.transparent,
          borderRadius: BorderRadius.circular(SimuTokens.radius),
        ),
        child: Row(
          children: [
            DeviceGlyph(device: device, busy: busy),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.label,
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: t.mono.copyWith(fontSize: 11)),
                ],
              ),
            ),
            if (busy)
              const Padding(padding: EdgeInsets.all(7), child: SimuSpinner())
            else
              for (final action in deviceActions(context, device, state))
                SimuIconButton(
                  icon: _actionIcon(action.kind),
                  tooltip: action.label,
                  size: 15,
                  onPressed: action.onPressed,
                ),
          ],
        ),
      ),
    );
  }
}

/// Form-factor icon on a platform tint, with a state dot in the corner.
class DeviceGlyph extends StatelessWidget {
  const DeviceGlyph({super.key, required this.device, this.busy = false});

  final Device device;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final tint = device.os == DeviceOs.android ? t.android : t.apple;
    return SizedBox.square(
      dimension: 32,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(SimuTokens.radius),
            ),
            child: Icon(
              switch (DeviceFormFactor.of(device)) {
                DeviceFormFactor.phone => LucideIcons.smartphone,
                DeviceFormFactor.tablet => LucideIcons.tablet,
                DeviceFormFactor.tv => LucideIcons.tv,
                DeviceFormFactor.watch => LucideIcons.watch,
              },
              size: 16,
              color: tint,
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: SimuStatusDot(
              size: 10,
              ring: t.sidebar,
              color: busy
                  ? t.warning
                  : device.state == DeviceState.booted
                  ? t.success
                  : t.textFaint,
            ),
          ),
        ],
      ),
    );
  }
}
