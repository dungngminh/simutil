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

  /// Ticks or unticks [id] as a device to run on. Unticking one while
  /// "all" is on keeps every other device; ticking the last one goes back
  /// to "all", which follows devices as they come and go.
  void _toggleDevice(String id) => setState(() {
    if (_allDevices) {
      _allDevices = false;
      _selectedIds
        ..clear()
        ..addAll([
          for (final d in _available)
            if (d.id != id) d.id,
        ]);
    } else if (!_selectedIds.remove(id)) {
      _selectedIds.add(id);
    }
    if (_available.every((d) => _selectedIds.contains(d.id))) {
      _allDevices = true;
      _selectedIds.clear();
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
                  return _DeviceBar(
                    devices: _available,
                    isTarget: (id) => _allDevices || _selectedIds.contains(id),
                    run: run,
                    steps: run == null ? 0 : flowStepLines(run.source).length,
                    focused: focused,
                    editable: !running,
                    onToggle: _toggleDevice,
                    onFocus: (id) => setState(() => _focus = id),
                    onClear: running
                        ? null
                        : () => setState(() {
                            _focus = null;
                            // Ids restart, so the next run must load anew.
                            _shownRun = null;
                            _runs.clear();
                          }),
                  );
                },
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

/// One line for devices and the run: a button naming who runs (or whose
/// results show) that opens the device list, and the run's headline.
class _DeviceBar extends StatelessWidget {
  const _DeviceBar({
    required this.devices,
    required this.isTarget,
    required this.run,
    required this.steps,
    required this.focused,
    required this.editable,
    required this.onToggle,
    required this.onFocus,
    required this.onClear,
  });

  /// Streamed, running devices the flow can run on.
  final List<Device> devices;
  final bool Function(String id) isTarget;
  final ScenarioRun? run;

  /// How many top-level steps the run's flow has.
  final int steps;

  /// The device whose log and steps show; null for all.
  final ScenarioDeviceRun? focused;

  /// Whether the run targets can change (not while a flow runs).
  final bool editable;
  final void Function(String id) onToggle;
  final ValueChanged<String?> onFocus;

  /// Clears every finished run's results; null while one runs.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final run = this.run;
    final targets = devices.where((d) => isTarget(d.id)).length;
    final passed = run?.devices
        .where((d) => d.status == ScenarioStatus.ok)
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: [
          MenuAnchor(
            style: MenuStyle(
              backgroundColor: WidgetStatePropertyAll(t.panel),
              surfaceTintColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
              padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SimuTokens.radiusLarge),
                  side: BorderSide(color: t.border),
                ),
              ),
            ),
            menuChildren: [
              _DevicePopup(
                devices: devices,
                isTarget: isTarget,
                run: run,
                steps: steps,
                focus: focused?.deviceId,
                editable: editable,
                onToggle: onToggle,
                onFocus: onFocus,
              ),
            ],
            builder: (context, controller, _) => _DeviceButton(
              label: switch (focused) {
                final d? => d.name,
                null when devices.isEmpty => 'No devices',
                null when targets == devices.length =>
                  '${devices.length} device${devices.length == 1 ? '' : 's'}',
                null => '$targets of ${devices.length} devices',
              },
              status: focused?.status,
              open: controller.isOpen,
              onTap: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            ),
          ),
          if (focused != null)
            SimuIconButton(
              icon: LucideIcons.x,
              tooltip: 'Show every device',
              size: 13,
              onPressed: () => onFocus(null),
            ),
          const Spacer(),
          if (run != null) ...[
            ScenarioStatusIcon(status: run.status, size: 13),
            const SizedBox(width: 6),
            Text('Run #${run.id + 1}', style: t.label),
            const SizedBox(width: 6),
            Text(
              TimeOfDay.fromDateTime(run.startedAt).format(context),
              style: t.caption,
            ),
            const SizedBox(width: 8),
            Text(
              '$passed/${run.devices.length}',
              style: t.mono.copyWith(color: t.textFaint),
            ),
            const SizedBox(width: 4),
            SimuIconButton(
              icon: LucideIcons.eraser,
              tooltip: 'Clear results',
              size: 14,
              onPressed: onClear,
            ),
          ],
        ],
      ),
    );
  }
}

/// The bar's button: a phone icon (or the focused device's status), a
/// label, and a chevron.
class _DeviceButton extends StatelessWidget {
  const _DeviceButton({
    required this.label,
    required this.open,
    required this.onTap,
    this.status,
  });

  final String label;
  final bool open;
  final VoidCallback onTap;
  final ScenarioStatus? status;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return SimuHoverable(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: SimuTokens.motion,
        height: 28,
        padding: const EdgeInsets.only(left: 8, right: 6),
        decoration: BoxDecoration(
          color: open || hovered ? t.hover : t.raised,
          borderRadius: BorderRadius.circular(SimuTokens.radiusSmall),
          border: Border.all(color: t.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status case final status?)
              ScenarioStatusIcon(status: status, size: 12)
            else
              Icon(LucideIcons.smartphone, size: 13, color: t.textMuted),
            const SizedBox(width: 6),
            Text(label, style: t.caption.copyWith(color: t.text)),
            const SizedBox(width: 4),
            Icon(
              open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
              size: 12,
              color: t.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

/// The device list: tick a device to run on it; click a row to show its
/// log and step statuses ("All devices" shows everyone's). Each row with a
/// result shows its steps as a bar, how many passed, its status and time.
class _DevicePopup extends StatelessWidget {
  const _DevicePopup({
    required this.devices,
    required this.isTarget,
    required this.run,
    required this.steps,
    required this.focus,
    required this.editable,
    required this.onToggle,
    required this.onFocus,
  });

  final List<Device> devices;
  final bool Function(String id) isTarget;
  final ScenarioRun? run;
  final int steps;
  final String? focus;
  final bool editable;
  final void Function(String id) onToggle;
  final ValueChanged<String?> onFocus;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final results = {for (final d in run?.devices ?? const []) d.deviceId: d};
    // Streamed devices, then any the run used that no longer stream.
    final rows = <({String id, String name, DeviceOs? os, bool live})>[
      for (final d in devices) (id: d.id, name: d.name, os: d.os, live: true),
      for (final d in run?.devices ?? const <ScenarioDeviceRun>[])
        if (!devices.any((x) => x.id == d.deviceId))
          (id: d.deviceId, name: d.name, os: null, live: false),
    ];
    return SizedBox(
      width: 380,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
            child: Row(
              children: [
                Text('DEVICES', style: t.overline),
                const Spacer(),
                Text(
                  'Tick to run on · click to view',
                  style: t.caption.copyWith(color: t.textFaint),
                ),
              ],
            ),
          ),
          if (run != null)
            _DeviceRow(
              name: 'All devices',
              selected: focus == null,
              onTap: () => onFocus(null),
              trailing: ScenarioStatusIcon(status: run!.status, size: 13),
            ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Stream a device to run on', style: t.caption),
            ),
          for (final row in rows)
            _DeviceRow(
              name: row.name,
              dot: switch (row.os) {
                DeviceOs.android => t.android,
                DeviceOs.ios => t.apple,
                null => null,
              },
              checked: row.live ? isTarget(row.id) : null,
              onCheck: row.live && editable ? () => onToggle(row.id) : null,
              selected: focus == row.id,
              onTap: results.containsKey(row.id) ? () => onFocus(row.id) : null,
              result: results[row.id],
              steps: steps,
            ),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.name,
    required this.selected,
    this.onTap,
    this.dot,
    this.checked,
    this.onCheck,
    this.result,
    this.steps = 0,
    this.trailing,
  });

  final String name;
  final bool selected;

  /// Shows this device's log and steps; null when it has no result.
  final VoidCallback? onTap;
  final Color? dot;

  /// Whether the flow runs on it; null hides the checkbox.
  final bool? checked;
  final VoidCallback? onCheck;
  final ScenarioDeviceRun? result;
  final int steps;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final result = this.result;
    final done = result == null
        ? 0
        : [
            for (var i = 0; i < steps; i++) result.stepStatus(i),
          ].where((s) => s == ScenarioStatus.ok).length;
    final row = SimuHoverable(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: SimuTokens.motion,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? t.accent.withValues(alpha: 0.12)
              : hovered && onTap != null
              ? t.hover
              : Colors.transparent,
          borderRadius: BorderRadius.circular(SimuTokens.radius),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: switch (checked) {
                final checked? => SimuHoverable(
                  onTap: onCheck,
                  builder: (context, _) => Icon(
                    checked ? LucideIcons.squareCheck : LucideIcons.square,
                    size: 14,
                    color: onCheck == null
                        ? t.textFaint
                        : checked
                        ? t.accent
                        : t.textMuted,
                  ),
                ),
                null => null,
              },
            ),
            if (dot case final dot?) ...[
              SimuStatusDot(color: dot, size: 6),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: t.caption.copyWith(
                  color: selected ? t.accent : t.text,
                  fontWeight: selected ? FontWeight.w600 : null,
                ),
              ),
            ),
            if (result != null && steps > 0) ...[
              SizedBox(
                width: 84,
                child: _StepBar(device: result, steps: steps),
              ),
              SizedBox(
                width: 38,
                child: Text(
                  '$done/$steps',
                  textAlign: TextAlign.right,
                  style: t.mono.copyWith(color: t.textFaint),
                ),
              ),
            ],
            if (result != null) ...[
              const SizedBox(width: 8),
              ScenarioStatusIcon(status: result.status, size: 13),
              SizedBox(
                width: 30,
                child: Text(
                  result.seconds == null ? '' : '${result.seconds}s',
                  textAlign: TextAlign.right,
                  style: t.mono.copyWith(color: t.textFaint),
                ),
              ),
            ],
            ?trailing,
          ],
        ),
      ),
    );
    final error = result?.error;
    return error == null ? row : Tooltip(message: error, child: row);
  }
}

/// One segment per step: green passed, red failed, accent running, grey
/// not reached.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.device, required this.steps});

  final ScenarioDeviceRun device;
  final int steps;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Row(
      children: [
        for (var i = 0; i < steps; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: switch (device.stepStatus(i)) {
                  ScenarioStatus.ok => t.success,
                  ScenarioStatus.failed => t.danger,
                  ScenarioStatus.running => t.accent,
                  _ => t.border,
                },
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
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
