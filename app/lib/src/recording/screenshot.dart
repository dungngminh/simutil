import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:simutil_app/src/stream/ios/ios_device_session.dart';
import 'package:simutil_core/simutil_core.dart';

/// PNG of [device]'s screen at full resolution; a USB iOS device must be
/// streaming.
///
/// Screenshots need binary stdout, which CommandExec does not keep.
Future<List<int>> deviceScreenshot(Device device, String adbPath) async {
  if (device.os == DeviceOs.android) {
    final result = await Process.run(adbPath, [
      '-s',
      device.id,
      'exec-out',
      'screencap',
      '-p',
    ], stdoutEncoding: null);
    if (result.exitCode != 0) throw StateError('${result.stderr}');
    return result.stdout as List<int>;
  }
  if (device.type.isPhysical) return IosDeviceSession.screenshot(device.id);
  final file = File(
    '${Directory.systemTemp.path}/simutil-shot-${device.id}.png',
  );
  final result = await Process.run('xcrun', [
    'simctl',
    'io',
    device.id,
    'screenshot',
    '--type=png',
    file.path,
  ]);
  if (result.exitCode != 0) throw StateError('${result.stderr}');
  final bytes = await file.readAsBytes();
  await file.delete();
  return bytes;
}

/// PNG of the [RepaintBoundary] under [boundaryKey] (the stream grid) at
/// the screen's pixel ratio.
Future<List<int>> boundaryScreenshot(GlobalKey boundaryKey) async {
  final boundary = boundaryKey.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary || !boundary.hasSize) {
    throw StateError('Nothing to capture yet');
  }
  final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
  final image = await boundary.toImage(pixelRatio: view?.devicePixelRatio ?? 1);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('Could not encode the screenshot');
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// `<directory>/simutil-<name>-<timestamp>.png`, written with [png].
Future<String> saveScreenshot(
  String directory,
  String name,
  List<int> png,
) async {
  final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  final file = File('$directory/simutil-$name-$stamp.png');
  await file.writeAsBytes(png);
  return file.path;
}
