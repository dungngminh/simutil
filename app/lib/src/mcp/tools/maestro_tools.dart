import 'package:simutil_app/src/maestro/maestro_runner.dart';
import 'package:simutil_app/src/mcp/mcp_server.dart';
import 'package:simutil_app/src/mcp/tools/tool_context.dart';
import 'package:simutil_core/simutil_core.dart';

/// Running Maestro flows on one or many devices at once (replaces the old
/// step-based scenarios). The single input tools (tap, swipe, …) stay for
/// ad-hoc control.
List<McpTool> maestroTools(ToolContext c) => [
  McpTool(
    name: 'run_maestro',
    description:
        'Run a Maestro flow on one or more devices in parallel (the same flow '
        'on every device at once). flow is Maestro YAML: an appId, '
        'then "---", then commands such as launchApp, tapOn, assertVisible, '
        'assertNotVisible, inputText, swipe, scroll, back. devices are ids or '
        'names; omit to use every streamed device (they must be booted). '
        'Needs the Maestro CLI installed. Returns each device\'s pass/fail, '
        'duration and first failure.',
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
        targets = [
          for (final id in ids) c.find({'device': id}),
        ];
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
      final devices = {for (final d in booted) d.id: d.name};
      final runs = c.runs;
      try {
        final result = runs != null
            ? await runs.runFlow(c.maestro, flow, devices)
            : await c.maestro.run(
                flowYaml: flow,
                deviceIds: devices.keys.toList(),
              );
        c.devices.notify(
          'Maestro: ${result.passed}/${result.total} passed',
          error: !result.ok,
        );
        return c.text(result.toJson());
      } on MaestroNotInstalled catch (e) {
        return c.text(e.message);
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
      return c.text(
        wasRunning || ids.isNotEmpty ? 'Stopped' : 'Nothing running',
      );
    },
  ),
];
