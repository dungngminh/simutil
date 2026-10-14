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
  final _text = ScenarioSyntaxController(text: scenarioTemplate);
  final _runs = getIt<ScenarioRunsCubit>();
  final _maestro = getIt<MaestroRunner>();
  final _streams = getIt<StreamsCubit>();

  bool _running = false;
  int? _runId;
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
    final runId = _runs.start({
      for (final d in devices) d.id: d.name,
    }, source: _text.text);
    setState(() => _runId = runId);
    try {
      final result = await _maestro.run(
        flowYaml: _text.text,
        deviceIds: [for (final d in devices) d.id],
        onLine: (l) => _runs.appendLine(runId, l),
      );
      for (var i = 0; i < devices.length; i++) {
        final shard = result.shardFor(devices[i].id, i);
        _runs.setDevice(
          runId,
          devices[i].id,
          status: shard != null && shard.passed
              ? ScenarioStatus.ok
              : ScenarioStatus.failed,
          seconds: shard?.seconds,
          error: shard == null
              ? 'No result from Maestro'
              : shard.passed
              ? null
              : 'Flow failed',
        );
      }
    } on MaestroNotInstalled catch (e) {
      _runs.failAll(runId, e.message);
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      _runs.failAll(runId, '$e');
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  void _stop() {
    _maestro.stop();
    if (_runId case final id?) _runs.stop(id);
  }

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Container(
      color: t.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(onClose: widget.onClose),
          BlocSignalBuilder<StreamsCubit, StreamsState>(
            bloc: _streams,
            builder: (context, _) {
              final available = _available;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: _Toolbar(
                      running: _running,
                      fileName: _file,
                      targetCount: _targets.length,
                      onRun: _run,
                      onStop: _stop,
                      onOpen: _open,
                      onLoadSample: _running ? null : _loadSample,
                      onReset: _running
                          ? null
                          : () => setState(() {
                              _text.text = scenarioTemplate;
                              _file = null;
                            }),
                    ),
                  ),
                  if (available.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: _DeviceSelector(
                        devices: available,
                        allDevices: _allDevices,
                        selectedIds: _selectedIds,
                        enabled: !_running,
                        onSelectAll: _selectAll,
                        onToggleDevice: _toggleDevice,
                      ),
                    ),
                ],
              );
            },
          ),
          if (_error case final error?)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: _Banner(message: error),
            ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: ScenarioCodeEditor(controller: _text, readOnly: _running),
            ),
          ),
          Expanded(
            flex: 2,
            child: BlocSignalBuilder<ScenarioRunsCubit, List<ScenarioRun>>(
              bloc: _runs,
              builder: (context, runs) {
                final run = _runId == null
                    ? runs.firstOrNull
                    : runs.where((r) => r.id == _runId).firstOrNull;
                return _Results(run: run);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Scenarios', style: t.title),
                Text(
                  'Maestro flows, run in parallel',
                  style: t.caption.copyWith(color: t.textFaint),
                ),
              ],
            ),
          ),
          SimuIconButton(
            icon: LucideIcons.x,
            tooltip: 'Close',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.running,
    required this.fileName,
    required this.targetCount,
    required this.onRun,
    required this.onStop,
    required this.onOpen,
    required this.onLoadSample,
    required this.onReset,
  });

  final bool running;
  final String? fileName;
  final int targetCount;
  final VoidCallback onRun;
  final VoidCallback onStop;
  final VoidCallback onOpen;
  final void Function(ScenarioSample sample)? onLoadSample;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Row(
      children: [
        if (running)
          SimuButton(label: 'Stop', icon: LucideIcons.square, onPressed: onStop)
        else
          SimuButton(
            label: 'Run',
            icon: LucideIcons.play,
            primary: true,
            onPressed: onRun,
          ),
        const SizedBox(width: 6),
        SimuIconButton(
          icon: LucideIcons.folderOpen,
          tooltip: 'Open a .yaml flow',
          size: 15,
          onPressed: running ? null : onOpen,
        ),
        _SamplesMenu(onLoadSample: onLoadSample),
        SimuIconButton(
          icon: LucideIcons.rotateCcw,
          tooltip: 'Reset to the template',
          size: 15,
          onPressed: onReset,
        ),
        const Spacer(),
        Text(
          running
              ? 'Running…'
              : '$targetCount device${targetCount == 1 ? '' : 's'}',
          style: t.caption.copyWith(color: t.textFaint),
        ),
      ],
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
            leadingIcon: Icon(LucideIcons.fileCode, size: 14, color: t.accent),
            onPressed: onLoadSample == null
                ? null
                : () => onLoadSample!(sample),
            child: Text(sample.name, style: t.caption.copyWith(color: t.text)),
          ),
      ],
      builder: (context, controller, _) => SimuIconButton(
        icon: LucideIcons.sparkles,
        tooltip: 'Load a sample flow',
        size: 15,
        onPressed: onLoadSample == null
            ? null
            : () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: t.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(SimuTokens.radiusSmall),
        border: Border.all(color: t.danger.withValues(alpha: 0.4)),
      ),
      child: Text(
        message,
        style: t.caption.copyWith(color: t.danger),
      ),
    );
  }
}

/// The latest run's per-device outcome and Maestro's live log.
class _Results extends StatelessWidget {
  const _Results({required this.run});

  final ScenarioRun? run;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    if (run == null) {
      return Center(
        child: Text(
          'Run a flow to see results',
          style: t.caption.copyWith(color: t.textFaint),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 1,
          color: t.border,
          margin: const EdgeInsets.only(bottom: 8),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in run!.devices) _DevicePill(device: d),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: t.page,
              borderRadius: BorderRadius.circular(SimuTokens.radiusSmall),
              border: Border.all(color: t.border),
            ),
            child: SingleChildScrollView(
              reverse: true,
              child: SelectableText(
                run!.lines.isEmpty ? '…' : run!.lines.join('\n'),
                style: t.mono.copyWith(fontSize: 10.5, color: t.textMuted),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DevicePill extends StatelessWidget {
  const _DevicePill({required this.device});

  final ScenarioDeviceRun device;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final (label, color) = switch (device.status) {
      ScenarioStatus.running => ('running', t.accent),
      ScenarioStatus.ok => (
        device.seconds == null ? 'passed' : 'passed ${device.seconds}s',
        t.success,
      ),
      ScenarioStatus.failed => ('failed', t.danger),
    };
    final pill = SimuStatusPill(label: '${device.name} · $label', color: color);
    return device.error == null ? pill : Tooltip(message: device.error!, child: pill);
  }
}

/// Picks which streamed devices the flow runs on: an "All devices" chip plus
/// one chip per device. "All" follows the streamed devices as they come and go;
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
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _DeviceChip(
          label: 'All devices',
          icon: LucideIcons.layoutGrid,
          selected: allDevices,
          enabled: enabled,
          onTap: onSelectAll,
        ),
        for (final d in devices)
          _DeviceChip(
            label: d.name,
            dotColor: d.os == DeviceOs.android
                ? SimuTokens.of(context).android
                : SimuTokens.of(context).apple,
            selected: allDevices || selectedIds.contains(d.id),
            enabled: enabled,
            onTap: () => onToggleDevice(d.id),
          ),
      ],
    );
  }
}

class _DeviceChip extends StatelessWidget {
  const _DeviceChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.icon,
    this.dotColor,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return SimuHoverable(
      onTap: enabled ? onTap : null,
      builder: (context, hovered) {
        final fg = selected
            ? t.accent
            : (enabled ? t.textMuted : t.textFaint);
        return AnimatedContainer(
          duration: SimuTokens.motion,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? t.accent.withValues(alpha: 0.14)
                : (hovered && enabled ? t.hover : Colors.transparent),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? t.accent : t.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected)
                Icon(LucideIcons.check, size: 12, color: fg)
              else if (icon != null)
                Icon(icon, size: 12, color: fg)
              else if (dotColor != null)
                SimuStatusDot(color: dotColor!, size: 6),
              const SizedBox(width: 5),
              Text(
                label,
                style: t.caption.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
