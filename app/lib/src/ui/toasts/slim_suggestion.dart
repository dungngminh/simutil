import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_app/src/stream/streams_state.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_core/simutil_core.dart';

/// Height of [SlimSuggestionToast]: title, up to six subtitle lines,
/// buttons.
const kSlimSuggestionHeight = 170.0;

/// Whether to suggest Slim mode: two or more simulators are streamed, the
/// mode is off and at least one of them still runs every background
/// service.
bool shouldSuggestSlim({
  required List<StreamEntry> entries,
  required Set<String> slimmed,
  required bool slimEnabled,
}) {
  if (slimEnabled) return false;
  final simulators = [
    for (final e in entries)
      if (e.device.os == DeviceOs.ios && !e.device.type.isPhysical) e.device.id,
  ];
  return simulators.length >= 2 &&
      simulators.any((id) => !slimmed.contains(id));
}

/// Suggests Slim mode once several simulators stream.
class SlimSuggestionToast extends StatelessWidget {
  const SlimSuggestionToast({
    super.key,
    required this.onUseSlim,
    required this.onClose,
  });

  final VoidCallback onUseSlim;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return SimuToast(
      height: kSlimSuggestionHeight,
      icon: LucideIcons.leaf,
      tone: t.accent,
      title: 'Run simulators in Slim mode?',
      subtitle:
          'Turns off background services in each simulator (widgets, Siri, '
          'iCloud, Photos, telemetry…) so several stay smooth: roughly 4 GB '
          '→ 1 GB of memory each. Open simulators reboot; switch back any '
          'time with the leaf button in the toolbar.',
      subtitleLines: 6,
      onClose: onClose,
      actions: [
        SimuButton(
          label: 'Use Slim',
          primary: true,
          onPressed: () {
            onUseSlim();
            onClose();
          },
        ),
        SimuButton(label: 'Not now', onPressed: onClose),
      ],
    );
  }
}
