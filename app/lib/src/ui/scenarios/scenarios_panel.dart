import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_app/src/scenarios/scenario_runs_cubit.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_app/src/ui/scenarios/scenario_editor.dart';

/// Scenario runs from agents, newest first, step by step: a spinner on the
/// step running, a check on steps done, the error on a step that failed.
class ScenariosPanel extends StatelessWidget {
  const ScenariosPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final runs = context.value<ScenarioRunsCubit, List<ScenarioRun>>();
    return Container(
      decoration: BoxDecoration(
        color: t.sidebar,
        border: Border(left: BorderSide(color: t.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(onClose: onClose, canClear: runs.isNotEmpty),
          Expanded(
            child: runs.isEmpty
                ? const _EmptyRuns()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: runs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _RunCard(run: runs[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.onClose, required this.canClear});

  final VoidCallback onClose;
  final bool canClear;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(child: Text('Scenarios', style: t.title)),
            SimuIconButton(
              icon: LucideIcons.filePen,
              tooltip: 'Write a scenario',
              onPressed: () => showScenarioEditor(context),
            ),
            SimuIconButton(
              icon: LucideIcons.brushCleaning,
              tooltip: 'Clear finished',
              onPressed: canClear
                  ? context.read<ScenarioRunsCubit>().clearFinished
                  : null,
            ),
            SimuIconButton(
              icon: LucideIcons.x,
              tooltip: 'Hide scenarios',
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRuns extends StatelessWidget {
  const _EmptyRuns();

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Scenarios you or an agent (over MCP) run show up here, '
              'step by step.',
              style: t.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SimuButton(
              label: 'Write a scenario',
              icon: LucideIcons.filePen,
              onPressed: () => showScenarioEditor(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// One run: when and on which devices, then each step with its status.
class _RunCard extends StatelessWidget {
  const _RunCard({required this.run});

  final ScenarioRun run;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final time = TimeOfDay.fromDateTime(run.startedAt).format(context);
    return SimuPanel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusIcon(status: run.status),
              const SizedBox(width: 8),
              Expanded(child: Text('Scenario #${run.id + 1}', style: t.label)),
              Text(time, style: t.caption),
            ],
          ),
          const SizedBox(height: 4),
          _DevicesLine(devices: run.devices),
          const SizedBox(height: 6),
          for (final (i, step) in run.steps.indexed)
            _StepRow(run: run, index: i, text: step),
        ],
      ),
    );
  }
}

/// The run's devices on one line, each with its own status.
class _DevicesLine extends StatelessWidget {
  const _DevicesLine({required this.devices});

  final List<ScenarioDeviceRun> devices;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 2,
      children: [
        for (final d in devices)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusIcon(status: d.status, size: 11),
              const SizedBox(width: 4),
              Text(d.name, style: t.caption),
              if (d.ms case final ms?)
                Text(
                  ' · ${(ms / 1000).toStringAsFixed(1)} s',
                  style: t.caption,
                ),
            ],
          ),
      ],
    );
  }
}

/// One step: its status across devices, what it does, and the error of
/// each device that failed on it.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.run, required this.index, required this.text});

  final ScenarioRun run;
  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final status = run.stepStatus(index);
    final many = run.devices.length > 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusIcon(status: status, size: 14),
              const SizedBox(width: 8),
              Text('${index + 1}.', style: t.caption),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  text,
                  style: status == ScenarioStatus.pending
                      ? t.body.copyWith(color: t.textFaint)
                      : t.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (many && status == ScenarioStatus.running)
                Text(
                  '${run.passed(index)}/${run.devices.length}',
                  style: t.mono,
                ),
            ],
          ),
          for (final (device, error) in run.stepErrors(index))
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 2),
              child: SelectableText(
                many ? '$device: $error' : error,
                style: t.caption.copyWith(color: t.danger),
                maxLines: 4,
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status, this.size = 16});

  final ScenarioStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return switch (status) {
      ScenarioStatus.pending => Icon(
        LucideIcons.circle,
        size: size,
        color: t.textFaint,
      ),
      ScenarioStatus.running => SimuSpinner(size: size - 2),
      ScenarioStatus.ok => Icon(
        LucideIcons.circleCheck,
        size: size,
        color: t.success,
      ),
      ScenarioStatus.failed => Icon(
        LucideIcons.circleX,
        size: size,
        color: t.danger,
      ),
    };
  }
}
