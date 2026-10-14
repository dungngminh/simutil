import 'package:simutil_app/src/maestro/maestro_runner.dart';
import 'package:simutil_app/src/mcp/mcp_server.dart';
import 'package:simutil_app/src/mcp/tools/tool_context.dart';
import 'package:simutil_app/src/scenarios/scenario_runs_cubit.dart';
import 'package:simutil_core/simutil_core.dart';

/// Running Maestro flows on one or many devices at once (replaces the old
/// step-based scenarios). The single input tools (tap, swipe, …) stay for
/// ad-hoc control.
List<McpTool> maestroTools(ToolContext c) => [
  McpTool(
    name: 'run_maestro',
    description:
        'Run a Maestro flow on one or more devices in parallel (the same flow '
        'on every device, one shard each). flow is Maestro YAML: an appId, '
        'then "---", then commands such as launchApp, tapOn, assertVisible, '
        'assertNotVisible, inputText, swipe, scroll, back. devices are ids or '
        'names; omit to use every streamed device (they must be booted). '
        'Needs the Maestro CLI installed. Returns each device\'s pass/fail '
        'and duration.',
    properties: {
      'flow': {'type': 'string', 'description': 'Maestro flow YAML'},
      'devices': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Device ids or names; omit for every streamed device',
      },
    },
    required: ['flow'],
    handler: (args) async {
      final flow = args['flow'];
      if (flow is! String || flow.trim().isEmpty) {
        throw ArgumentError('flow (Maestro YAML) required');
      }
      final ids = args['devices'];
      final List<Device> targets;
      if (ids == null) {
        targets = [for (final e in c.streams.stateValue.entries) e.device];
      } else if (ids is List) {
        targets = [for (final id in ids) c.find({'device': id})];
      } else {
        throw ArgumentError('devices must be a list of ids or names');
      }
      final booted = [
        for (final d in targets)
          if (d.isRunning) d,
      ];
      if (booted.isEmpty) {
        throw ArgumentError(
          'No booted devices: start or stream some first, or pass devices',
        );
      }
      final deviceIds = [for (final d in booted) d.id];
      final runId = c.runs?.start({
        for (final d in booted) d.id: d.name,
      }, source: flow);
      try {
        final result = await c.maestro.run(
          flowYaml: flow,
          deviceIds: deviceIds,
          onLine: runId == null ? null : (l) => c.runs?.appendLine(runId, l),
        );
        // --shard-all assigns devices to shards in the --device order; match
        // each result back to its device rather than by list position, since a
        // missing shard would otherwise shift every later device's result.
        if (runId != null) {
          for (var i = 0; i < booted.length; i++) {
            final shard = result.shardFor(booted[i].id, i);
            c.runs?.setDevice(
              runId,
              booted[i].id,
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
        }
        c.devices.notify(
          'Maestro: ${result.passed}/${result.total} passed',
          error: !result.ok,
        );
        return c.text(result.toJson());
      } on MaestroNotInstalled catch (e) {
        if (runId != null) c.runs?.failAll(runId, e.message);
        return c.text(e.message);
      } catch (e) {
        if (runId != null) c.runs?.failAll(runId, '$e');
        rethrow;
      }
    },
  ),
  McpTool(
    name: 'stop_maestro',
    description: 'Stop the running Maestro flow (kills the maestro process).',
    handler: (_) async {
      final wasRunning = c.maestro.running;
      c.maestro.stop();
      final ids = c.runs?.stopAll() ?? const [];
      return c.text(wasRunning || ids.isNotEmpty ? 'Stopped' : 'Nothing running');
    },
  ),
];
