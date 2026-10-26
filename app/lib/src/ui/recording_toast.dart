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
import 'package:simutil_app/src/ui/toasts/update_toast.dart';
import 'package:simutil_app/src/update/app_update_cubit.dart';
import 'package:simutil_app/src/windows/device_windows.dart';
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

/// A toast with a title of up to two lines (plus an optional mono
/// [subtitle] of up to four); errors stay longer. [busy] shows a spinner and keeps it up
/// until the returned callback hides it.
VoidCallback showNotice(
  BuildContext context,
  String title, {
  String? subtitle,
  NoticeTone tone = NoticeTone.info,
  bool busy = false,
}) {
  final t = SimuTokens.of(context);
  final (icon, color) = switch (tone) {
    NoticeTone.info => (LucideIcons.info, t.accent),
    NoticeTone.success => (LucideIcons.circleCheck, t.success),
    NoticeTone.error => (LucideIcons.circleAlert, t.danger),
  };
  final titleLines = _lines(title, SimuToast.titleStyle(t), 2);
  final subtitleLines = subtitle == null
      ? 1
      : _lines(subtitle, SimuToast.subtitleStyle(t), 4);
  // Each extra line adds one 16 px line, so heights stay on the 4 px grid.
  final height =
      (subtitle == null ? 52.0 : 60.0) +
      (titleLines + subtitleLines - 2) * SimuToast.lineHeight;
  final toast = showSimuToast(
    context,
    height,
    (close) => SimuToast(
      height: height,
      icon: icon,
      tone: color,
      busy: busy,
      title: title,
      titleLines: titleLines,
      subtitle: subtitle,
      subtitleLines: subtitleLines,
      onClose: close,
    ),
    hideAfter: busy
        ? null
        : Duration(seconds: tone == NoticeTone.error ? 8 : 4),
  );
  final toasts = ToastProvider.of(context);
  return () => toasts.hide(toast);
}

/// How many lines (1..[max]) [text] takes in a [showNotice] toast.
/// The text width is the toast viewer's 380 minus the toast's border,
/// padding, icon and close button.
int _lines(String text, TextStyle style, int max) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: max,
  )..layout(maxWidth: 286);
  final lines = painter.computeLineMetrics().length;
  painter.dispose();
  return lines.clamp(1, max);
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
  StreamSubscription<DeviceNotice>? _deviceNotices;
  StreamSubscription<DeviceMove>? _moves;
  void Function()? _unsubscribeStreams;
  var _statuses = <String, SessionStatus>{};

  /// The "Opening…" toast per device id, replaced once the stream settles.
  final _opening = <String, Toast>{};

  /// "Starting…" toast per device name, from Start-and-stream until the
  /// booted device's stream opens.
  final _starting = <String, Toast>{};
  var _booting = <String>{};

  /// The Slim suggestion shows once per app session.
  var _slimSuggested = false;

  void Function()? _unsubscribeSlim;
  void Function()? _unsubscribeUpdate;
  var _slimApplying = false;

  /// "Switching…" toast while open simulators reboot into the new mode.
  Toast? _slimSwitching;

  /// Hides each device's loading toast (wipe, delete) once its result shows.
  final _deviceBusy = <String, VoidCallback>{};

  static const _streamHeight = 60.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_unsubscribeStreams != null) return;
    _saved = getIt<SavedRecordings>().saved.listen(_onSaved);
    _deviceNotices = getIt<DevicesCubit>().notices.listen(_onDeviceNotice);
    _moves = getIt.maybeGet<DeviceWindows>()?.moves.listen(_onMove);
    final streams = getIt<StreamsCubit>();
    // Seeded first so the immediate subscribe call announces nothing.
    _statuses = _statusesOf(streams.stateValue);
    _booting = streams.stateValue.booting;
    _unsubscribeStreams = streams.state.subscribe(_onStreams);
    if (getIt.isRegistered<SlimModeCubit>()) {
      _unsubscribeSlim = getIt<SlimModeCubit>().state.subscribe(_onSlimMode);
    }
    if (getIt.isRegistered<AppUpdateCubit>()) {
      final current = getIt<AppUpdateCubit>().currentVersion;
      versionBeforeUpdate(current: current).then((previous) {
        if (previous == null || !mounted) return;
        showNotice(
          context,
          'Updated to SimUtil $current',
          subtitle: 'From $previous',
          tone: NoticeTone.success,
        );
      });
      // Once per launch; the sidebar button reopens it.
      _unsubscribeUpdate = getIt<AppUpdateCubit>().state.subscribe((update) {
        if (update == null || !mounted) return;
        _unsubscribeUpdate?.call();
        showUpdateToast(context, update);
      });
    }
  }

  void _onDeviceNotice(DeviceNotice n) {
    if (!mounted) return;
    final id = n.deviceId;
    if (id != null) _deviceBusy.remove(id)?.call();
    final hide = showNotice(
      context,
      n.text,
      busy: n.kind == DeviceNoticeKind.busy,
      tone: switch (n.kind) {
        DeviceNoticeKind.info || DeviceNoticeKind.busy => NoticeTone.info,
        DeviceNoticeKind.success => NoticeTone.success,
        DeviceNoticeKind.error => NoticeTone.error,
      },
    );
    if (id != null && n.kind == DeviceNoticeKind.busy) _deviceBusy[id] = hide;
  }

  void _onMove(DeviceMove move) {
    if (!mounted) return;
    final name = move.device.name;
    if (move.back) {
      showNotice(
        context,
        '$name is back in the main window',
        tone: NoticeTone.success,
      );
    } else {
      showNotice(
        context,
        '$name opened in its own window',
        subtitle: 'Back to the main window or close it to return',
      );
    }
  }

  @override
  void dispose() {
    _saved?.cancel();
    _deviceNotices?.cancel();
    _moves?.cancel();
    _unsubscribeStreams?.call();
    _unsubscribeSlim?.call();
    _unsubscribeUpdate?.call();
    super.dispose();
  }

  static Map<String, SessionStatus> _statusesOf(StreamsState state) => {
    for (final e in state.entries) e.device.id: e.status,
  };

  /// Shows "Starting `name`…" right when Start-and-stream is pressed, so
  /// the boot wait is visible; removed once the stream opens.
  void _onBooting(Set<String> booting) {
    for (final name in _booting.difference(booting)) {
      _hide(_starting.remove(name));
    }
    final t = SimuTokens.of(context);
    for (final name in booting.difference(_booting)) {
      _starting[name] = _show(
        _streamHeight,
        (close) => SimuToast(
          height: _streamHeight,
          icon: LucideIcons.power,
          tone: t.accent,
          busy: true,
          title: 'Starting $name…',
          subtitle: 'It streams here once booted',
          onClose: close,
        ),
        hideAfter: const Duration(minutes: 3),
      );
    }
    _booting = booting;
  }

  /// Tells the user while a Slim / default switch reboots simulators, and
  /// when it is done.
  void _onSlimMode(SlimModeState state) {
    if (!mounted || state.applying == _slimApplying) return;
    _slimApplying = state.applying;
    final t = SimuTokens.of(context);
    final mode = state.enabled ? 'Slim mode' : 'Default mode';
    if (state.applying) {
      _slimSwitching = _show(
        60,
        (close) => SimuToast(
          height: 60,
          icon: LucideIcons.leaf,
          tone: t.accent,
          busy: true,
          title: 'Switching to $mode…',
          subtitle: 'Simulators reboot, streams reconnect',
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
        title: '$mode on',
        subtitle: state.enabled
            ? 'New simulators start slim'
            : 'All services back',
        onClose: close,
      ),
      hideAfter: const Duration(seconds: 3),
    );
  }

  void _onStreams(StreamsState state) {
    if (!mounted) return;
    _onBooting(state.booting);
    final changes = streamToastChanges(_statuses, state);
    final next = _statusesOf(state);
    for (final id in _statuses.keys) {
      if (!next.containsKey(id)) _hide(_opening.remove(id));
    }
    final previous = _statuses;
    _statuses = next;
    for (final entry in changes) {
      _announce(entry, wasLive: previous[entry.device.id] is SessionLive);
    }
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

  void _announce(StreamEntry entry, {bool wasLive = false}) {
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
            icon: wasLive ? LucideIcons.unplug : LucideIcons.circleAlert,
            tone: wasLive ? t.warning : t.danger,
            // A live stream that drops was disconnected, not failed.
            title: wasLive
                ? '${device.name} stream closed'
                : '${device.name} failed',
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
    final image = path.endsWith('.png');
    _show(
      100,
      (close) => SimuToast(
        height: 100,
        icon: image ? LucideIcons.image : LucideIcons.film,
        tone: image ? t.accent : t.danger,
        title: image ? 'Screenshot saved' : 'Recording saved',
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
