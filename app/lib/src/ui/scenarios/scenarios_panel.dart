import 'dart:async';
import 'dart:io';

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_app/src/di.dart';
import 'package:simutil_app/src/mcp/tools/input_tools.dart';
import 'package:simutil_app/src/mcp/tools/tool_context.dart';
import 'package:simutil_app/src/scenarios/scenario_runs_cubit.dart';
import 'package:simutil_app/src/scenarios/scenario_yaml.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_app/src/ui/scenarios/scenario_code_editor.dart';
import 'package:simutil_app/src/ui/scenarios/scenario_syntax.dart';

/// Scenario studio: the scenario's YAML, editable in place, with each
/// step's status in the gutter while it runs (a spinner, a check, a cross)
/// and failures listed under the editor. Scenarios agents run over MCP show
/// here as YAML too.
class ScenariosPanel extends StatefulWidget {
  const ScenariosPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<ScenariosPanel> createState() => _ScenariosPanelState();
}

class _ScenariosPanelState extends State<ScenariosPanel> {
  final _text = ScenarioSyntaxController(text: scenarioTemplate);
  int? _shownRun;

  /// A finished run whose results the user cleared.
  int? _clearedRun;
  String? _error;
  String? _file;

  @override
  void initState() {
    super.initState();
    _text.addListener(_onEdit);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Statuses follow the text (shown only while it is what ran), so every
  /// edit rebuilds; it also clears a stale YAML error.
  void _onEdit() => setState(() => _error = null);

  /// Shows a run that just started (an agent's replaces the editor text).
  void _follow(ScenarioRun? latest) {
    if (latest == null || latest.id == _shownRun) return;
    _shownRun = latest.id;
    if (latest.source.isEmpty || latest.source == _text.text) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _text.text = latest.source;
    });
  }

  Future<void> _open() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Scenario', extensions: ['yaml', 'yml']),
      ],
    );
    if (file == null) return;
    final text = await File(file.path).readAsString();
    setState(() => _file = file.name);
    _text.text = text;
  }

  void _run() {
    final source = _text.text;
    final Map<String, Object?> args;
    final ToolContext tools;
    try {
      args = scenarioFromYaml(source);
      tools = getIt<ToolContext>();
      parseScenario(tools, args);
    } on FormatException catch (e) {
      return setState(() => _error = e.message);
    } on ArgumentError catch (e) {
      return setState(() => _error = '${e.message}');
    }
    unawaited(
      runScenario(tools, args, source: source).then<void>(
        (_) {},
        onError: (Object e) {
          if (mounted) setState(() => _error = '$e');
        },
      ),
    );
  }

  void _goToLine(int line) {
    final offset = _text.text
        .split('\n')
        .take(line)
        .fold<int>(0, (sum, l) => sum + l.length + 1);
    _text.selection = TextSelection.collapsed(offset: offset);
  }

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final newest = context
        .value<ScenarioRunsCubit, List<ScenarioRun>>()
        .firstOrNull;
    _follow(newest);
    final latest = newest?.id == _clearedRun ? null : newest;
    // Statuses map to lines only while the text is what ran.
    final run = latest != null && latest.source == _text.text ? latest : null;
    final running = latest?.status == ScenarioStatus.running;
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
            onRun: _run,
            onStop: () {
              if (latest != null) {
                context.read<ScenarioRunsCubit>().stop(latest.id);
              }
            },
            onClose: widget.onClose,
          ),
          if (latest != null)
            _RunSummary(
              run: latest,
              onClear: running ? null : () => _clear(latest),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ScenarioCodeEditor(
                controller: _text,
                readOnly: running,
                marks: run == null ? const {} : _marks(run),
                devices: _streamedDevices(),
              ),
            ),
          ),
          _Problems(
            error: _error,
            run: run,
            onTap: _goToLine,
            onClear: running ? null : () => _clear(latest),
          ),
        ],
      ),
    );
  }

  /// Names of streamed devices, offered in `devices: [...]`.
  List<String> _streamedDevices() => getIt.isRegistered<StreamsCubit>()
      ? [
          for (final e in getIt<StreamsCubit>().stateValue.entries)
            e.device.name,
        ]
      : const [];

  /// Hides [run]'s results (statuses, errors) and any YAML error.
  void _clear(ScenarioRun? run) => setState(() {
    _clearedRun = run?.id ?? _clearedRun;
    _error = null;
  });

  /// Each step's status and errors, keyed by its first line.
  Map<int, LineMark> _marks(ScenarioRun run) => {
    for (final (i, line) in run.lines.indexed)
      if (i < run.steps.length)
        line: (
          status: run.stepStatus(i),
          message: [
            for (final (device, error) in run.stepErrors(i))
              run.devices.length > 1 ? '$device: $error' : error,
          ].join('\n'),
        ),
  };
}

class _StudioHeader extends StatelessWidget {
  const _StudioHeader({
    required this.file,
    required this.running,
    required this.onOpen,
    required this.onRun,
    required this.onStop,
    required this.onClose,
  });

  final String? file;
  final bool running;
  final VoidCallback onOpen;
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
                file ?? '',
                style: t.caption,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SimuIconButton(
              icon: LucideIcons.folderOpen,
              tooltip: 'Open a .yaml file',
              onPressed: running ? null : onOpen,
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

/// The latest run on one line: status, when, how many devices passed,
/// failed or still run; expands to each device.
class _RunSummary extends StatefulWidget {
  const _RunSummary({required this.run, this.onClear});

  final ScenarioRun run;

  /// Clears the run's results; null while it runs.
  final VoidCallback? onClear;

  @override
  State<_RunSummary> createState() => _RunSummaryState();
}

class _RunSummaryState extends State<_RunSummary> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final run = widget.run;
    final time = TimeOfDay.fromDateTime(run.startedAt).format(context);
    int count(ScenarioStatus s) =>
        run.devices.where((d) => d.status == s).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ScenarioStatusIcon(status: run.status, size: 13),
              const SizedBox(width: 6),
              Text('Run #${run.id + 1} · $time', style: t.caption),
              const SizedBox(width: 10),
              for (final s in [
                ScenarioStatus.ok,
                ScenarioStatus.failed,
                ScenarioStatus.running,
              ])
                if (count(s) > 0) _CountChip(status: s, count: count(s)),
              const Spacer(),
              SimuIconButton(
                icon: _expanded
                    ? LucideIcons.chevronUp
                    : LucideIcons.chevronDown,
                tooltip: _expanded ? 'Hide devices' : 'Show devices',
                size: 14,
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
              if (widget.onClear case final clear?)
                SimuIconButton(
                  icon: LucideIcons.eraser,
                  tooltip: 'Clear results',
                  size: 14,
                  onPressed: clear,
                ),
            ],
          ),
          if (_expanded) _DeviceList(devices: run.devices),
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
      padding: const EdgeInsets.only(right: 8),
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

class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.devices});

  final List<ScenarioDeviceRun> devices;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final d in devices)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScenarioStatusIcon(status: d.status, size: 11),
                const SizedBox(width: 4),
                Text(
                  d.ms == null
                      ? d.name
                      : '${d.name} · ${(d.ms! / 1000).toStringAsFixed(1)} s',
                  style: t.caption,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// YAML errors, or the steps that failed (tap one to jump to its line).
class _Problems extends StatelessWidget {
  const _Problems({
    required this.error,
    required this.run,
    required this.onTap,
    this.onClear,
  });

  final String? error;
  final ScenarioRun? run;
  final void Function(int line) onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final run = this.run;
    final failures = [
      if (run != null)
        for (final (i, line) in run.lines.indexed)
          if (i < run.steps.length)
            for (final (device, message) in run.stepErrors(i))
              (
                line: line,
                text:
                    'Line ${line + 1} · ${run.steps[i]}\n'
                    '${run.devices.length > 1 ? '$device: ' : ''}$message',
              ),
    ];
    if (error == null && failures.isEmpty) return const SizedBox(height: 12);
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
                if (onClear case final clear?)
                  GestureDetector(
                    onTap: clear,
                    child: Text(
                      'Clear',
                      style: t.caption.copyWith(color: t.textMuted),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (error case final error?) _ProblemLine(text: error),
            for (final f in failures)
              _ProblemLine(text: f.text, onTap: () => onTap(f.line)),
          ],
        ),
      ),
    );
  }
}

class _ProblemLine extends StatelessWidget {
  const _ProblemLine({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.circleX, size: 14, color: t.danger),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text, style: t.caption.copyWith(color: t.danger)),
            ),
          ],
        ),
      ),
    );
  }
}
