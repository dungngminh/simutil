import 'dart:io';

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_app/src/di.dart';
import 'package:simutil_app/src/maestro/maestro_runner.dart';
import 'package:simutil_app/src/scenarios/scenario_runs_cubit.dart';
import 'package:simutil_app/src/scenarios/scenario_yaml.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_app/src/stream/streams_state.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_app/src/ui/scenarios/scenario_code_editor.dart';
import 'package:simutil_app/src/ui/scenarios/scenario_syntax.dart';

/// Scenario studio: a Maestro flow, editable in place, run on every streamed
/// device at once (in parallel), with each device's pass/fail and Maestro's
/// live log below the editor.
class ScenariosPanel extends StatefulWidget {
  const ScenariosPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<ScenariosPanel> createState() => _ScenariosPanelState();
}

class _ScenariosPanelState extends State<ScenariosPanel> {
  final _runs = getIt<ScenarioRunsCubit>();
  final _maestro = getIt<MaestroRunner>();
  final _streams = getIt<StreamsCubit>();
  late final _text = ScenarioSyntaxController(
    text: scenarioTemplate(_targetOs),
  );

  bool _running = false;

  /// The newest run the editor has caught up with.
  int? _shownRun;

  /// The device whose log and step statuses show; null shows them all.
  String? _focus;
  String? _error;
  String? _file;

  /// Run on every streamed device; when false, only [_selectedIds] run.
  bool _allDevices = true;
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Every streamed, running device the flow could run on.
  List<Device> get _available => [
    for (final e in _streams.stateValue.entries)
      if (e.device.isRunning) e.device,
  ];

  /// The devices the flow will actually run on, honouring the selection.
  List<Device> get _targets {
    final available = _available;
    if (_allDevices) return available;
    return [
      for (final d in available)
        if (_selectedIds.contains(d.id)) d,
    ];
  }

  /// iOS when every target is iOS, else Android: picks the template.
  DeviceOs get _targetOs {
    final targets = _targets;
    return targets.isNotEmpty && targets.every((d) => d.os == DeviceOs.ios)
        ? DeviceOs.ios
        : DeviceOs.android;
  }

  /// Swaps an unedited template for the targets' platform's one.
  void _syncTemplate() {
    final want = scenarioTemplate(_targetOs);
    if (_text.text == want) return;
    if (!DeviceOs.values.any((os) => _text.text == scenarioTemplate(os))) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _text.text = want;
    });
  }

  void _selectAll() => setState(() {
    _allDevices = true;
    _selectedIds.clear();
  });

  void _toggleDevice(String id) => setState(() {
    if (_allDevices) {
      // Leaving "all": start an explicit selection with just this device.
      _allDevices = false;
      _selectedIds
        ..clear()
        ..add(id);
    } else {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
      // Never get stuck with nothing selected.
      if (_selectedIds.isEmpty) _allDevices = true;
    }
  });

  void _loadSample(ScenarioSample sample) => setState(() {
    _text.text = sample.flow;
    _file = null;
    _error = null;
  });

  Future<void> _open() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Maestro flow', extensions: ['yaml', 'yml']),
      ],
    );
    if (file == null) return;
    try {
      final text = await File(file.path).readAsString();
      if (!mounted) return;
      setState(() {
        _file = file.name;
        _text.text = text;
        _error = null;
      });
    } on FileSystemException catch (e) {
      if (mounted) setState(() => _error = 'Could not open ${file.name}: $e');
    }
  }

  Future<void> _run() async {
    if (_running) return;
    final flow = _text.text.trim();
    if (flow.isEmpty) {
      setState(() => _error = 'The flow is empty');
      return;
    }
    final devices = _targets;
    if (devices.isEmpty) {
      setState(
        () => _error = _available.isEmpty
            ? 'Stream at least one device first'
            : 'Select at least one device to run on',
      );
      return;
    }
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      await _runs.runFlow(_maestro, _text.text, {
        for (final d in devices) d.id: d.name,
      });
    } on MaestroNotInstalled catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  /// Loads a run that just started into the editor when its flow differs
  /// (an agent's, over MCP), so its steps get statuses too.
  void _follow(ScenarioRun? run) {
    if (run == null || run.id == _shownRun) return;
    _shownRun = run.id;
    if (!run.devices.any((d) => d.deviceId == _focus)) _focus = null;
    if (run.source.isEmpty || run.source == _text.text) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _text.text = run.source;
      setState(() {
        _file = null;
        _error = null;
      });
    });
  }

  /// Each step's status on [devices], keyed by its line.
  Map<int, LineMark> _marks(String source, List<ScenarioDeviceRun> devices) => {
    for (final (step, line) in flowStepLines(source).indexed)
      line: ?_mark(devices, step),
  };

  /// Failed if [step] failed on any of [devices], running if it runs on
  /// any, passed once it passed on all; null before it starts.
  LineMark? _mark(List<ScenarioDeviceRun> devices, int step) {
    final many = devices.length > 1;
    List<ScenarioDeviceRun> on(ScenarioStatus s) => [
      for (final d in devices)
        if (d.stepStatus(step) == s) d,
    ];
    final failed = on(ScenarioStatus.failed);
    if (failed.isNotEmpty) {
      return (
        status: ScenarioStatus.failed,
        message: [
          for (final d in failed)
            many ? '${d.name}: ${d.error ?? 'Failed'}' : d.error ?? 'Failed',
        ].join('\n'),
      );
    }
    final running = on(ScenarioStatus.running);
    if (running.isNotEmpty) {
      return (
        status: ScenarioStatus.running,
        message: many
            ? 'Running on ${running.map((d) => d.name).join(', ')}'
            : 'Running',
      );
    }
    if (on(ScenarioStatus.ok).length == devices.length) {
      return (status: ScenarioStatus.ok, message: 'Passed');
    }
    return null;
  }

  /// Stops [run], also one an agent started over MCP.
  void _stop(ScenarioRun? run) {
    _maestro.stop();
    if (run != null) _runs.stop(run.id);
  }

  void _reset() => setState(() {
    _text.text = scenarioTemplate(_targetOs);
    _file = null;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return BlocSignalBuilder<ScenarioRunsCubit, List<ScenarioRun>>(
      bloc: _runs,
      builder: (context, runs) {
        final run = runs.firstOrNull;
        _follow(run);
        final focused = run?.devices
            .where((d) => d.deviceId == _focus)
            .firstOrNull;
        // A run an agent started over MCP shows here too.
        final latest = run;
        final running = _running || latest?.status == ScenarioStatus.running;
        return Container(
          decoration: BoxDecoration(
            color: t.sidebar,
            border: Border(left: BorderSide(color: t.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StudioHeader(
                file: _file,
                running: running,
                onOpen: _open,
                onLoadSample: _loadSample,
                onReset: _reset,
                onRun: _run,
                onStop: () => _stop(running && !_running ? latest : run),
                onClose: widget.onClose,
              ),
              BlocSignalBuilder<StreamsCubit, StreamsState>(
                bloc: _streams,
                builder: (context, _) {
                  _syncTemplate();
                  return _DeviceSelector(
                    devices: _available,
                    allDevices: _allDevices,
                    selectedIds: _selectedIds,
                    enabled: !running,
                    onSelectAll: _selectAll,
                    onToggleDevice: _toggleDevice,
                  );
                },
              ),
              if (run != null)
                _RunSummary(
                  run: run,
                  focus: focused?.deviceId,
                  onFocus: (id) => setState(() => _focus = id),
                ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ScenarioCodeEditor(
                    controller: _text,
                    readOnly: running,
                    // Statuses map to lines only while the text is what ran.
                    marks: run != null && run.source == _text.text
                        ? _marks(
                            run.source,
                            focused == null ? run.devices : [focused],
                          )
                        : const {},
                  ),
                ),
              ),
              if (run != null)
                Expanded(
                  flex: 2,
                  child: _Output(
                    device: focused?.name,
                    lines: focused?.lines ?? run.lines,
                  ),
                ),
              _Problems(
                error: _error,
                onClear: () => setState(() => _error = null),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Title, the open file, and the studio's actions: open, samples, reset,
/// Run / Stop, close.
class _StudioHeader extends StatelessWidget {
  const _StudioHeader({
    required this.file,
    required this.running,
    required this.onOpen,
    required this.onLoadSample,
    required this.onReset,
    required this.onRun,
    required this.onStop,
    required this.onClose,
  });

  final String? file;
  final bool running;
  final VoidCallback onOpen;
  final void Function(ScenarioSample sample) onLoadSample;
  final VoidCallback onReset;
  final VoidCallback onRun;
  final VoidCallback onStop;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Text('Scenario', style: t.title),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                file ?? 'Maestro flow',
                style: t.caption,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SimuIconButton(
              icon: LucideIcons.folderOpen,
              tooltip: 'Open a .yaml flow',
              onPressed: running ? null : onOpen,
            ),
            _SamplesMenu(onLoadSample: running ? null : onLoadSample),
            SimuIconButton(
              icon: LucideIcons.rotateCcw,
              tooltip: 'Reset to the template',
              onPressed: running ? null : onReset,
            ),
            const SizedBox(width: 4),
            SimuButton(
              label: running ? 'Stop' : 'Run',
              icon: running ? LucideIcons.square : LucideIcons.play,
              primary: true,
              onPressed: running ? onStop : onRun,
            ),
            const SizedBox(width: 4),
            SimuIconButton(
              icon: LucideIcons.x,
              tooltip: 'Hide scenario',
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

/// Drop-down that loads one of the built-in [scenarioSamples] into the editor.
class _SamplesMenu extends StatelessWidget {
  const _SamplesMenu({required this.onLoadSample});

  final void Function(ScenarioSample sample)? onLoadSample;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return MenuAnchor(
      menuChildren: [
        for (final sample in scenarioSamples)
          MenuItemButton(
            leadingIcon: SimuStatusDot(
              color: sample.os == DeviceOs.ios ? t.apple : t.android,
              size: 6,
            ),
            trailingIcon: Text(
              sample.os.label,
              style: t.mono.copyWith(color: t.textFaint),
            ),
            onPressed: onLoadSample == null
                ? null
                : () => onLoadSample!(sample),
            child: Text(sample.name, style: t.caption.copyWith(color: t.text)),
          ),
      ],
      builder: (context, controller, _) => SimuIconButton(
        icon: LucideIcons.sparkles,
        tooltip: 'Load a sample flow',
        onPressed: onLoadSample == null
            ? null
            : () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// Picks which streamed devices the flow runs on: an "All" chip plus one
/// chip per device. "All" follows the streamed devices as they come and go;
/// picking a device switches to an explicit selection.
class _DeviceSelector extends StatelessWidget {
  const _DeviceSelector({
    required this.devices,
    required this.allDevices,
    required this.selectedIds,
    required this.enabled,
    required this.onSelectAll,
    required this.onToggleDevice,
  });

  final List<Device> devices;
  final bool allDevices;
  final Set<String> selectedIds;
  final bool enabled;
  final VoidCallback onSelectAll;
  final void Function(String id) onToggleDevice;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: Text('RUN ON', style: t.overline),
          ),
          Expanded(
            child: devices.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Stream a device to run on', style: t.caption),
                  )
                : Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _DeviceChip(
                        label: 'All',
                        selected: allDevices,
                        enabled: enabled,
                        onTap: onSelectAll,
                      ),
                      for (final d in devices)
                        _DeviceChip(
                          label: d.name,
                          dot: d.os == DeviceOs.android ? t.android : t.apple,
                          selected: allDevices || selectedIds.contains(d.id),
                          enabled: enabled,
                          onTap: () => onToggleDevice(d.id),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// A device to run on, as a checkbox: outlined, with a tick when picked,
/// so it reads as a choice rather than the run's results below.
class _DeviceChip extends StatelessWidget {
  const _DeviceChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.dot,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  /// Platform color; none for "All".
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return SimuHoverable(
      onTap: enabled ? onTap : null,
      builder: (context, hovered) => AnimatedOpacity(
        duration: SimuTokens.motion,
        opacity: enabled ? 1 : 0.5,
        child: AnimatedContainer(
          duration: SimuTokens.motion,
          height: 26,
          padding: const EdgeInsets.only(left: 6, right: 9),
          decoration: BoxDecoration(
            color: hovered && enabled ? t.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(SimuTokens.radiusSmall),
            border: Border.all(
              color: selected ? t.accent.withValues(alpha: 0.5) : t.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? LucideIcons.squareCheck : LucideIcons.square,
                size: 13,
                color: selected ? t.accent : t.textFaint,
              ),
              const SizedBox(width: 6),
              if (dot case final dot?) ...[
                SimuStatusDot(color: dot, size: 6),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: t.caption.copyWith(
                  color: selected ? t.text : t.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The run's headline (status, number, time, device counts) and, with
/// several devices, a segmented control choosing whose log and step
/// statuses show: all devices, or one.
class _RunSummary extends StatelessWidget {
  const _RunSummary({
    required this.run,
    required this.focus,
    required this.onFocus,
  });

  final ScenarioRun run;

  /// The focused device's id; null for all.
  final String? focus;
  final ValueChanged<String?> onFocus;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final time = TimeOfDay.fromDateTime(run.startedAt).format(context);
    int count(ScenarioStatus s) =>
        run.devices.where((d) => d.status == s).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ScenarioStatusIcon(status: run.status, size: 13),
              const SizedBox(width: 6),
              Text('Run #${run.id + 1}', style: t.label),
              const SizedBox(width: 6),
              Text(time, style: t.caption),
              const Spacer(),
              for (final s in ScenarioStatus.values)
                if (count(s) > 0) _CountChip(status: s, count: count(s)),
            ],
          ),
          if (run.devices.length > 1) ...[
            const SizedBox(height: 8),
            _DeviceTabs(run: run, focus: focus, onFocus: onFocus),
          ],
        ],
      ),
    );
  }
}

/// How many devices are in [status], beside its icon.
class _CountChip extends StatelessWidget {
  const _CountChip({required this.status, required this.count});

  final ScenarioStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScenarioStatusIcon(status: status, size: 11),
          const SizedBox(width: 3),
          Text('$count', style: t.caption),
        ],
      ),
    );
  }
}

/// Segmented control over the run's devices: "All", then each device with
/// its status and time. Scrolls sideways when the devices do not fit.
class _DeviceTabs extends StatelessWidget {
  const _DeviceTabs({
    required this.run,
    required this.focus,
    required this.onFocus,
  });

  final ScenarioRun run;
  final String? focus;
  final ValueChanged<String?> onFocus;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: t.raised,
        borderRadius: BorderRadius.circular(SimuTokens.radius),
        border: Border.all(color: t.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _DeviceTab(
              label: 'All',
              selected: focus == null,
              onTap: () => onFocus(null),
            ),
            for (final d in run.devices)
              _DeviceTab(
                label: d.name,
                status: d.status,
                trailing: d.seconds == null ? null : '${d.seconds}s',
                tooltip: d.error,
                selected: focus == d.deviceId,
                onTap: () => onFocus(d.deviceId),
              ),
          ],
        ),
      ),
    );
  }
}

class _DeviceTab extends StatelessWidget {
  const _DeviceTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.status,
    this.trailing,
    this.tooltip,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ScenarioStatus? status;

  /// Small monospace note after the label, e.g. the device's time.
  final String? trailing;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final tab = SimuHoverable(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: SimuTokens.motion,
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? t.panel
              : hovered
              ? t.hover
              : Colors.transparent,
          borderRadius: BorderRadius.circular(SimuTokens.radiusSmall),
          border: Border.all(color: selected ? t.border : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status case final status?) ...[
              ScenarioStatusIcon(status: status, size: 11),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: t.caption.copyWith(
                color: selected ? t.text : t.textMuted,
                fontWeight: selected ? FontWeight.w600 : null,
              ),
            ),
            if (trailing case final trailing?) ...[
              const SizedBox(width: 5),
              Text(trailing, style: t.mono.copyWith(color: t.textFaint)),
            ],
          ],
        ),
      ),
    );
    return tooltip == null ? tab : Tooltip(message: tooltip, child: tab);
  }
}

/// Maestro's live output for the run.
class _Output extends StatelessWidget {
  const _Output({required this.lines, this.device});

  final List<String> lines;

  /// The focused device's name; null when the log is every device's.
  final String? device;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 6),
          child: Text(
            device == null ? 'OUTPUT' : 'OUTPUT · ${device!.toUpperCase()}',
            style: t.overline,
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: t.raised,
              borderRadius: BorderRadius.circular(SimuTokens.radius),
              border: Border.all(color: t.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              reverse: true,
              padding: const EdgeInsets.all(10),
              child: SelectableText(
                lines.isEmpty ? 'Waiting for Maestro…' : lines.join('\n'),
                style: t.mono.copyWith(
                  fontSize: 11,
                  height: 1.45,
                  color: lines.isEmpty ? t.textFaint : t.textMuted,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The last error (an empty flow, no device, Maestro missing or failing).
class _Problems extends StatelessWidget {
  const _Problems({required this.error, required this.onClear});

  final String? error;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final error = this.error;
    if (error == null) return const SizedBox(height: 12);
    return Container(
      constraints: const BoxConstraints(maxHeight: 160),
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(SimuTokens.radius),
        border: Border.all(color: t.danger.withValues(alpha: 0.4)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Problems', style: t.label.copyWith(color: t.danger)),
                const Spacer(),
                SimuHoverable(
                  onTap: onClear,
                  builder: (context, hovered) => Text(
                    'Clear',
                    style: t.caption.copyWith(
                      color: hovered ? t.text : t.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.circleX, size: 14, color: t.danger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    error,
                    style: t.caption.copyWith(color: t.danger),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
