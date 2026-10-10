import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_app/src/di.dart';
import 'package:simutil_app/src/mcp/mcp_server.dart';
import 'package:simutil_app/src/mcp/tools/tool_context.dart';
import 'package:simutil_app/src/settings/device_settings_cubit.dart';
import 'package:simutil_app/src/settings/view_settings_cubit.dart';
import 'package:simutil_app/src/ui/streams/stream_layout.dart';
import 'package:simutil_core/simutil_core.dart';

/// Listing, booting, streaming and slimming devices; the spotlight.
List<McpTool> deviceTools(ToolContext c) => [
  McpTool(
    name: 'list_devices',
    description:
        'Android emulators/devices and iOS simulators/devices with their '
        'state, slim mode, whether they are streamed in SimUtil and, when '
        'recording, for how many seconds.',
    handler: (_) async {
      await c.devices.refresh(silent: true);
      final state = c.devices.stateValue;
      return c.text([
        for (final d in state.all)
          {
            'id': d.id,
            'name': d.name,
            'os': d.os.name,
            'type': d.type.name,
            'state': d.state.label,
            'slim': state.slimmed.contains(d.id),
            'streaming': c.streams.stateValue.isOpen(d.id),
            'recording_seconds': c.recordingSeconds(d.id),
          },
      ]);
    },
  ),
  McpTool(
    name: 'get_spotlight',
    description:
        'The stream layout, the device shown large in the spotlight '
        '(null in the grid layout or with no streams) and how long it and '
        'the whole grid have been recording.',
    handler: (_) async {
      final settings = c.view.stateValue;
      final entries = c.streams.stateValue.entries;
      final ids = [for (final e in entries) e.device.id];
      final id = settings.layout == StreamLayout.grid || ids.isEmpty
          ? null
          : spotlightFocus(ids, settings.spotlightId);
      final device = id == null
          ? null
          : entries.firstWhere((e) => e.device.id == id).device;
      return c.text({
        'layout': settings.layout.name,
        'device': device == null
            ? null
            : {
                'id': device.id,
                'name': device.name,
                'os': device.os.name,
                'recording_seconds': c.recordingSeconds(device.id),
              },
        'grid_recording_seconds': c.grid.isRecording
            ? c.grid.elapsed.inSeconds
            : null,
      });
    },
  ),
  McpTool(
    name: 'start_device',
    description:
        'Boot an emulator/simulator. headless (default true) skips its own '
        'window and streams it into SimUtil. Android: coldBoot and noAudio '
        "default to the device's launch options in SimUtil.",
    properties: {
      ...deviceArg,
      'headless': {'type': 'boolean'},
      'coldBoot': {'type': 'boolean'},
      'noAudio': {'type': 'boolean'},
    },
    required: ['device'],
    handler: (args) async {
      final device = c.find(args);
      final options = _launchOptions(device);
      final headless = args['headless'] as bool? ?? options.headless ?? true;
      if (headless) c.streams.openWhenBooted(device);
      await c.devices.launch(
        device,
        headless: headless,
        coldBoot: args['coldBoot'] as bool? ?? options.coldBoot,
        noAudio: args['noAudio'] as bool? ?? options.noAudio,
      );
      return c.text('Starting ${device.name}');
    },
  ),
  McpTool(
    name: 'connect_device',
    description:
        'adb connect to an Android device over Wi-Fi (host or host:port, '
        'port 5555 by default). For a device already paired or listening '
        'with adb tcpip.',
    properties: {
      'host': {'type': 'string'},
    },
    required: ['host'],
    handler: (args) async {
      final host = (args['host']! as String).trim();
      final target = host.contains(':') ? host : '$host:5555';
      final result = await getIt<AndroidDeviceService>().connectDevice(target);
      if (!result.success) throw StateError(result.message);
      await c.devices.refresh(silent: true);
      return c.text(result.message);
    },
  ),
  McpTool(
    name: 'pair_device',
    description:
        'Pair an Android 11+ device for wireless debugging with the host:port '
        'and six-digit code from Developer options › Wireless debugging › '
        'Pair device with pairing code, then connect it.',
    properties: {
      'host': {'type': 'string'},
      'code': {'type': 'string'},
    },
    required: ['host', 'code'],
    handler: (args) async {
      final result = await getIt<AdbWirelessPairing>().pairAndConnect(
        (args['host']! as String).trim(),
        (args['code']! as String).trim(),
      );
      if (!result.success) throw StateError(result.message);
      await c.devices.refresh(silent: true);
      return c.text(result.message);
    },
  ),
  McpTool(
    name: 'disconnect_device',
    description: 'adb disconnect a Wi-Fi Android device (host:port).',
    properties: {
      'host': {'type': 'string'},
    },
    required: ['host'],
    handler: (args) async {
      final host = (args['host']! as String).trim();
      await c.streams.closeStream(host);
      final ok = await getIt<AndroidDeviceService>().disconnectDevice(host);
      if (!ok) throw StateError('adb disconnect $host failed');
      await c.devices.refresh(silent: true);
      return c.text('Disconnected $host');
    },
  ),
  McpTool(
    name: 'shutdown_device',
    description: 'Shut down an emulator/simulator.',
    properties: deviceArg,
    required: ['device'],
    handler: (args) async {
      final device = c.find(args);
      await c.streams.closeStream(device.id);
      await c.devices.shutdown(device);
      return c.text('Shut down ${device.name}');
    },
  ),
  McpTool(
    name: 'stream_device',
    description: 'Show a running device in the SimUtil grid.',
    properties: deviceArg,
    required: ['device'],
    handler: (args) async {
      final device = c.find(args);
      await c.live(device);
      return c.text('Streaming ${device.name}');
    },
  ),
  McpTool(
    name: 'set_slim',
    description:
        'iOS simulator: disable (true) or restore (false) background '
        'services to save memory. Reboots a running simulator; its stream '
        'reopens afterwards.',
    properties: {
      ...deviceArg,
      'slim': {'type': 'boolean'},
    },
    required: ['device', 'slim'],
    handler: (args) async {
      final device = c.find(args);
      final want = args['slim']! as bool;
      await c.slim.setSlim(device, on: want);
      return c.text('${device.name} slim: $want');
    },
  ),
  McpTool(
    name: 'set_slim_mode',
    description:
        'Slim mode for all iOS simulators: true reboots every streamed '
        'simulator without background services and starts new ones slim; '
        'false restores them. Recommended when streaming 2+ simulators.',
    properties: {
      'enabled': {'type': 'boolean'},
    },
    required: ['enabled'],
    handler: (args) async {
      await c.slim.setMode(enabled: args['enabled']! as bool);
      return c.text('Slim mode: ${c.slim.stateValue.enabled}');
    },
  ),
];

/// The device's launch options from the UI, when the app's DI is up.
DeviceSettings _launchOptions(Device device) =>
    getIt.isRegistered<DeviceSettingsCubit>()
    ? getIt<DeviceSettingsCubit>().of(device)
    : const DeviceSettings();
