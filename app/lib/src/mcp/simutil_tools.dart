import 'package:simutil_app/src/devices/slim_mode_cubit.dart';
import 'package:simutil_app/src/devices/devices_cubit.dart';
import 'package:simutil_app/src/mcp/mcp_server.dart';
import 'package:simutil_app/src/mcp/tools/capture_tools.dart';
import 'package:simutil_app/src/mcp/tools/device_tools.dart';
import 'package:simutil_app/src/mcp/tools/input_tools.dart';
import 'package:simutil_app/src/mcp/tools/tool_context.dart';
import 'package:simutil_app/src/recording/grid_recorder.dart';
import 'package:simutil_app/src/settings/view_settings_cubit.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';

/// Tools that let an agent list, start, watch and drive devices; each group
/// lives in `tools/`.
List<McpTool> simutilTools({
  required DevicesCubit devices,
  required StreamsCubit streams,
  required GridRecorderCubit grid,
  required ViewSettingsCubit view,
  required SlimModeCubit slim,
  required String Function() adbPath,
}) {
  final context = ToolContext(
    devices: devices,
    streams: streams,
    grid: grid,
    view: view,
    slim: slim,
    adbPath: adbPath,
  );
  return [
    ...deviceTools(context),
    ...inputTools(context),
    ...captureTools(context),
  ];
}
