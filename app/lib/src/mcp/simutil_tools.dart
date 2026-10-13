import 'package:simutil_app/src/mcp/mcp_server.dart';
import 'package:simutil_app/src/mcp/tools/capture_tools.dart';
import 'package:simutil_app/src/mcp/tools/device_tools.dart';
import 'package:simutil_app/src/mcp/tools/input_tools.dart';
import 'package:simutil_app/src/mcp/tools/maestro_tools.dart';
import 'package:simutil_app/src/mcp/tools/tool_context.dart';

/// Tools that let an agent list, start, watch and drive devices, and run
/// Maestro flows across them; each group lives in `tools/`.
List<McpTool> simutilTools(ToolContext context) => [
  ...deviceTools(context),
  ...inputTools(context),
  ...maestroTools(context),
  ...captureTools(context),
];
