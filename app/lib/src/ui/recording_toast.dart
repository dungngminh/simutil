import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_app/src/devices/slim_mode_cubit.dart';
import 'package:simutil_app/src/di.dart';
import 'package:simutil_app/src/recording/saved_recordings.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_app/src/stream/streams_state.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_app/src/ui/toasts/slim_suggestion.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:zentoast/zentoast.dart';

/// Hosts the app's toasts in the bottom-right corner: stream open progress
/// ("Opening…" → live / failed), saved recordings, and anything shown with
/// [showSimuToast] / [showNotice]. Sits above the Navigator, so dialogs can
/// show toasts too.
class RecordingToastHost extends StatelessWidget {
  const RecordingToastHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ToastProvider.create(
      child: _ToastFeeds(
        child: Stack(
          children: [
            child,
            // Above the Navigator: own Overlay for the toasts' tooltips and a
            // transparent Material for their text, both passing taps through.
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: Overlay(
                  initialEntries: [OverlayEntry(builder: _viewer)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _viewer(BuildContext context) => const ToastThemeProvider(
  data: ToastTheme(viewerPadding: EdgeInsets.all(20), gap: 10),
  child: ToastViewer(
    alignment: Alignment.bottomRight,
    width: 380,
    // Hiding is timed per toast; an "Opening…" toast stays until its stream
    // settles.
    delay: null,
    visibleCount: 4,
  ),
);

/// Shows [card] as a toast from any context under [RecordingToastHost];
/// hidden after [hideAfter] when given. [card] gets a callback that hides it.
Toast showSimuToast(
  BuildContext context,
  double height,
  Widget Function(VoidCallback close) card, {
  Duration? hideAfter,
}) {
  final toasts = ToastProvider.of(context);
  late final Toast toast;
  toast = Toast(height: height, builder: (_) => card(() => toasts.hide(toast)));
  toasts.show(toast);
  if (hideAfter != null) Timer(hideAfter, () => toasts.hide(toast));
  return toast;
}

/// How a [showNotice] toast reads.
enum NoticeTone { info, success, error }

/// A one-line (plus optional mono [subtitle]) toast; errors stay longer.
void showNotice(
  BuildContext context,
  String title, {
  String? subtitle,
  NoticeTone tone = NoticeTone.info,
}) {
  final t = SimuTokens.of(context);
  final (icon, color) = switch (tone) {
    NoticeTone.info => (LucideIcons.info, t.accent),
    NoticeTone.success => (LucideIcons.circleCheck, t.success),
    NoticeTone.error => (LucideIcons.circleAlert, t.danger),
  };
  final height = subtitle == null ? 52.0 : 60.0;
  showSimuToast(
    context,
    height,
    (close) => SimuToast(
      height: height,
      icon: icon,
      tone: color,
      title: title,
      subtitle: subtitle,
      onClose: close,
    ),
    hideAfter: Duration(seconds: tone == NoticeTone.error ? 8 : 4),
  );
}

/// Entries whose status kind changed since [previous] (new entries
/// included); live-session resizes are not changes.
@visibleForTesting
List<StreamEntry> streamToastChanges(
  Map<String, SessionStatus> previous,
  StreamsState next,
) => [
  for (final entry in next.entries)
    if (previous[entry.device.id]?.runtimeType != entry.status.runtimeType)
      entry,
];

/// Turns StreamsCubit changes and saved recordings into toasts.
class _ToastFeeds extends StatefulWidget {
  const _ToastFeeds({required this.child});

  final Widget child;

  @override
  State<_ToastFeeds> createState() => _ToastFeedsState();
}

class _ToastFeedsState extends State<_ToastFeeds> {
  StreamSubscription<String>? _saved;
  void Function()? _unsubscribeStreams;
  var _statuses = <String, SessionStatus>{};

  /// The "Opening…" toast per device id, replaced once the stream settles.
  final _opening = <String, Toast>{};

  /// The Slim suggestion shows once per app session.
  var _slimSuggested = false;

  void Function()? _unsubscribeSlim;
  var _slimApplying = false;

  /// "Switching…" toast while open simulators reboot into the new mode.
  Toast? _slimSwitching;

  static const _streamHeight = 60.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_unsubscribeStreams != null) return;
    _saved = getIt<SavedRecordings>().saved.listen(_onSaved);
    final streams = getIt<StreamsCubit>();
    // Seeded first so the immediate subscribe call announces nothing.
    _statuses = _statusesOf(streams.stateValue);
    _unsubscribeStreams = streams.state.subscribe(_onStreams);
    if (getIt.isRegistered<SlimModeCubit>()) {
      _unsubscribeSlim = getIt<SlimModeCubit>().state.subscribe(_onSlimMode);
    }
  }

  @override
  void dispose() {
    _saved?.cancel();
    _unsubscribeStreams?.call();
    _unsubscribeSlim?.call();
    super.dispose();
  }

  static Map<String, SessionStatus> _statusesOf(StreamsState state) => {
    for (final e in state.entries) e.device.id: e.status,
  };

  /// Tells the user while a Slim / default switch reboots simulators, and
  /// when it is done.
  void _onSlimMode(SlimModeState state) {
    if (!mounted || state.applying == _slimApplying) return;
    _slimApplying = state.applying;
    final t = SimuTokens.of(context);
    final mode = state.enabled ? 'Slim mode' : 'Default mode';
    if (state.applying) {
      _slimSwitching = _show(
        76,
        (close) => SimuToast(
          height: 76,
          icon: LucideIcons.leaf,
          tone: t.accent,
          busy: true,
          title: 'Switching to $mode…',
          subtitle:
              'Open simulators reboot one at a time; their streams '
              'reconnect on their own.',
          subtitleLines: 2,
        ),
      );
      return;
    }
    _hide(_slimSwitching);
    _slimSwitching = null;
    _show(
      60,
      (close) => SimuToast(
        height: 60,
        icon: LucideIcons.leaf,
        tone: t.success,
        title: '$mode is on',
        subtitle: state.enabled
            ? 'New simulators start slim too'
            : 'Simulators run every service',
        onClose: close,
      ),
      hideAfter: const Duration(seconds: 3),
    );
  }

  void _onStreams(StreamsState state) {
    if (!mounted) return;
    final changes = streamToastChanges(_statuses, state);
    final next = _statusesOf(state);
    for (final id in _statuses.keys) {
      if (!next.containsKey(id)) _hide(_opening.remove(id));
    }
    _statuses = next;
    changes.forEach(_announce);
    _maybeSuggestSlim(state);
  }

  void _maybeSuggestSlim(StreamsState state) {
    if (_slimSuggested || !getIt.isRegistered<SlimModeCubit>()) return;
    final slimMode = getIt<SlimModeCubit>();
    if (!shouldSuggestSlim(
      entries: state.entries,
      slimmed: getIt<DevicesCubit>().stateValue.slimmed,
      slimEnabled: slimMode.stateValue.enabled,
    )) {
      return;
    }
    _slimSuggested = true;
    _show(
      kSlimSuggestionHeight,
      (close) => SlimSuggestionToast(
        onUseSlim: () => slimMode.setMode(enabled: true),
        onClose: close,
      ),
    );
  }

  void _announce(StreamEntry entry) {
    final device = entry.device;
    final opening = _opening.remove(device.id);
    _hide(opening);
    final t = SimuTokens.of(context);
    switch (entry.status) {
      case SessionConnecting():
        _opening[device.id] = _show(
          _streamHeight,
          (close) => SimuToast(
            height: _streamHeight,
            busy: true,
            icon: LucideIcons.cast,
            tone: t.accent,
            title: 'Opening ${device.name}…',
            subtitle: device.id,
            onClose: close,
          ),
        );
      // Only follows an "Opening…" toast; a dismissed one stays dismissed.
      case SessionLive(:final width, :final height) when opening != null:
        _show(
          _streamHeight,
          (close) => SimuToast(
            height: _streamHeight,
            icon: LucideIcons.circleCheck,
            tone: t.success,
            title: '${device.name} is live',
            subtitle: '$width×$height',
            onClose: close,
          ),
          hideAfter: const Duration(seconds: 3),
        );
      case SessionLive():
        break;
      case SessionFailed(:final message):
        _show(
          76,
          (close) => SimuToast(
            height: 76,
            icon: LucideIcons.circleAlert,
            tone: t.danger,
            title: '${device.name} failed',
            subtitle: message,
            subtitleLines: 2,
            onClose: close,
          ),
          hideAfter: const Duration(seconds: 8),
        );
    }
  }

  void _onSaved(String path) {
    if (!mounted) return;
    final t = SimuTokens.of(context);
    final recordings = getIt<SavedRecordings>();
    _show(
      100,
      (close) => SimuToast(
        height: 100,
        icon: LucideIcons.film,
        tone: t.danger,
        title: 'Recording saved',
        subtitle: path.split(RegExp(r'[/\\]')).last,
        onTap: () => recordings.open(path),
        onClose: close,
        actions: [
          SimuButton(
            label: 'Open',
            primary: true,
            onPressed: () => recordings.open(path),
          ),
          SimuButton(
            label: _revealLabel,
            icon: LucideIcons.folderOpen,
            onPressed: () => recordings.reveal(path),
          ),
        ],
      ),
      hideAfter: const Duration(seconds: 8),
    );
  }

  static String get _revealLabel => switch (Platform.operatingSystem) {
    'macos' => 'Show in Finder',
    'windows' => 'Show in Explorer',
    _ => 'Show in folder',
  };

  Toast _show(
    double height,
    Widget Function(VoidCallback close) card, {
    Duration? hideAfter,
  }) => showSimuToast(context, height, card, hideAfter: hideAfter);

  void _hide(Toast? toast) {
    if (toast != null && mounted) ToastProvider.of(context).hide(toast);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
