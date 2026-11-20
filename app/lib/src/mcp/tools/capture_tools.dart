import 'dart:convert';
import 'package:simutil_app/src/mcp/mcp_server.dart';
import 'package:simutil_app/src/mcp/tools/tool_context.dart';
import 'package:simutil_app/src/recording/grid_record_quality.dart';
import 'package:simutil_app/src/recording/screenshot.dart';
import 'package:simutil_app/src/settings/recordings_dir.dart';
import 'package:simutil_app/src/recording/capture_file.dart';

/// Screenshots and device / grid recordings.
List<McpTool> captureTools(ToolContext c) => [
  McpTool(
    name: 'screenshot',
    description: 'PNG screenshot of a running device.',
    properties: deviceArg,
    required: ['device'],
    handler: (args) async {
      final png = await deviceScreenshot(c.find(args), c.adbPath());
      return [
        {'type': 'image', 'data': base64Encode(png), 'mimeType': 'image/png'},
      ];
    },
  ),
  McpTool(
    name: 'record_device',
    description:
        'Start or stop recording a device to ~/Movies/SimUtil '
        '(~/Videos/SimUtil). Returns the file when stopping.',
    properties: deviceArg,
    required: ['device'],
    handler: (args) async {
      final device = c.find(args);
      await c.live(device);
      final path = await c.streams.toggleRecording(
        device.id,
        recordingsDirectory(),
      );
      return c.text(path == null ? 'Recording started' : 'Saved $path');
    },
  ),
  McpTool(
    name: 'record_grid',
    description:
        'Start or stop recording the whole SimUtil grid. quality: low '
        '(15 fps), standard (24 fps), high (30 fps, full resolution) or, on '
        'macOS, smooth (60 fps, full resolution); '
        "defaults to the app's choice. Only one recording (grid or device) "
        'runs at a time.',
    properties: {
      'quality': {
        'type': 'string',
        'enum': [for (final q in GridRecordQuality.available) q.name],
      },
    },
    handler: (args) async {
      if (c.grid.isRecording) return c.text('Saved ${await c.grid.stop()}');
      final quality =
          GridRecordQuality.available.asNameMap()[args['quality']] ??
          c.view.stateValue.gridQuality;
      await c.grid.start(
        captureFilePath(recordingsDirectory(), 'grid', 'mp4'),
        quality: quality,
      );
      return c.text('Recording grid (${quality.summary})');
    },
  ),
];
