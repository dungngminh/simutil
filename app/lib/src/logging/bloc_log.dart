import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart';
import 'package:simutil_app/src/devices/devices_state.dart';
import 'package:simutil_app/src/settings/device_settings_cubit.dart';
import 'package:simutil_app/src/settings/view_settings_cubit.dart';
import 'package:simutil_app/src/stream/streams_state.dart';
import 'package:simutil_core/simutil_core.dart';

/// Prints one readable line per cubit state change, e.g.
/// `[Streams] 2 open: Pixel 7 live 1080×2400, iPhone 16 connecting`.
/// Lines identical to the cubit's previous one are skipped.
class BlocLogObserver extends BlocSignalObserver {
  BlocLogObserver({this.print = _debugPrint});

  final void Function(String line) print;
  final _last = Expando<String>();

  static void _debugPrint(String line) => debugPrint(line);

  @override
  void onChange(BlocSignalBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    final line =
        '[${blocLabel(bloc)}] '
        '${describeState(change.nextState, previous: change.currentState)}';
    if (_last[bloc] == line) return;
    _last[bloc] = line;
    print(line);
  }
}

/// `StreamsCubit` → `Streams`.
String blocLabel(Object bloc) {
  final name = bloc.runtimeType.toString();
  return name.endsWith('Cubit')
      ? name.substring(0, name.length - 'Cubit'.length)
      : name;
}

/// One-line summary of a cubit state; [previous] narrows map states to
/// what changed.
String describeState(Object? state, {Object? previous}) => switch (state) {
  DevicesState() => _devices(state),
  StreamsState() => _streams(state),
  ViewSettings() => _view(state),
  Map<String, DeviceSettings>() => _deviceSettings(
    state,
    previous is Map<String, DeviceSettings> ? previous : const {},
  ),
  bool() => state ? 'recording' : 'idle',
  _ => _clip('$state'),
};

String _devices(DevicesState s) {
  final all = s.all;
  final booted = all.where((d) => d.state == DeviceState.booted).length;
  final busy = [
    for (final d in all)
      if (s.busy.contains(d.id)) d.name,
  ];
  return [
    '${all.length} devices ($booted booted)',
    'busy: ${busy.isEmpty ? 'none' : busy.join(', ')}',
    if (s.loading) 'refreshing',
    if (s.message case final m?) '"$m"',
  ].join(', ');
}

String _streams(StreamsState s) {
  final booting = s.booting.isEmpty ? '' : ', booting: ${s.booting.join(', ')}';
  if (s.entries.isEmpty) return 'none open$booting';
  final parts = [
    for (final e in s.entries)
      [
        e.device.name,
        switch (e.status) {
          SessionConnecting() => 'connecting',
          SessionLive(:final width, :final height) => 'live $width×$height',
          SessionFailed(:final message) => 'failed (${_clip(message, 60)})',
        },
        if (e.recording) 'rec',
      ].join(' '),
  ];
  return '${s.entries.length} open: ${parts.join(', ')}$booting';
}

String _view(ViewSettings s) => [
  'layout=${s.layout.name}',
  'headless=${_onOff(s.headless)}',
  if (s.spotlightId case final id?) 'spotlight=$id',
].join(' ');

String _deviceSettings(
  Map<String, DeviceSettings> next,
  Map<String, DeviceSettings> previous,
) {
  final changed = [
    for (final MapEntry(:key, :value) in next.entries)
      if (previous[key] != value) '$key: ${_settings(value)}',
  ];
  return changed.isEmpty ? '${next.length} devices' : changed.join('; ');
}

/// Only what differs from the defaults.
String _settings(DeviceSettings s) {
  const d = DeviceSettings();
  final parts = [
    if (s.headless case final h?) 'headless=${_onOff(h)}',
    if (s.showFrame != d.showFrame) 'frame=${_onOff(s.showFrame)}',
    if (s.coldBoot != d.coldBoot) 'coldBoot=${_onOff(s.coldBoot)}',
    if (s.noAudio != d.noAudio) 'noAudio=${_onOff(s.noAudio)}',
    if (s.maxSize != d.maxSize) 'maxSize=${s.maxSize}',
    if (s.maxFps != d.maxFps) 'maxFps=${s.maxFps}',
    if (s.bitRateMbps != d.bitRateMbps) 'bitRate=${s.bitRateMbps}M',
  ];
  return parts.isEmpty ? 'defaults' : parts.join(' ');
}

String _onOff(bool value) => value ? 'on' : 'off';

String _clip(String text, [int max = 120]) {
  final line = text.replaceAll('\n', ' ');
  return line.length <= max ? line : '${line.substring(0, max - 1)}…';
}
