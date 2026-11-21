import 'dart:async';

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:simutil_app/src/app.dart';
import 'package:simutil_app/src/devices/device_form_factor.dart';
import 'package:simutil_app/src/di.dart';
import 'package:simutil_app/src/stream/streams_cubit.dart';
import 'package:simutil_app/src/stream/streams_state.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_app/src/ui/recording_toast.dart';
import 'package:simutil_app/src/ui/streams/stream_tile.dart';
import 'package:simutil_app/src/windows/device_windows.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:window_manager/window_manager.dart';

/// Runs a device window's engine: its own services and one stream. The
/// window closes when the stream does, and closing it stops the stream.
Future<void> runDeviceWindow(WindowController window, Device device) async {
  await windowManager.ensureInitialized();
  await configureDependencies(deviceWindow: true);

  Future<void>? stopped;
  Future<void> stop() => stopped ??= disposeDependencies().catchError(
    (Object e) => debugPrint('Device window dispose failed: $e'),
  );
  var closing = false;
  Future<void> close({bool back = false}) async {
    if (closing) return;
    closing = true;
    await stop();
    if (back) {
      try {
        await DeviceWindows.sendBack(device);
      } catch (e) {
        debugPrint('Sending the device back failed: $e');
      }
    }
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  // Quitting the app: the main window waits for the stream to stop.
  await window.setWindowMethodHandler((call) async {
    if (call.method == DeviceWindows.closeMethod) await stop();
  });
  windowManager.addListener(_OnClose(close));
  await windowManager.setPreventClose(true);

  getIt<DeviceWindows>().backToMain = () => close(back: true);
  final streams = getIt<StreamsCubit>();
  unawaited(streams.open(device)); // adds the tile synchronously
  streams.state.subscribe((state) {
    if (state.entries.isEmpty) unawaited(close());
  });

  final phone = switch (DeviceFormFactor.of(device)) {
    DeviceFormFactor.phone || DeviceFormFactor.watch => true,
    _ => false,
  };
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      title: device.name,
      size: phone ? const Size(440, 860) : const Size(1040, 760),
      minimumSize: const Size(280, 360),
      center: true,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  runApp(
    SimutilApp(
      child: MaterialApp(
        title: device.name,
        debugShowCheckedModeBanner: false,
        theme: simuTheme(Brightness.light),
        darkTheme: simuTheme(Brightness.dark),
        builder: (context, child) => RecordingToastHost(child: child!),
        home: const _DeviceWindowHome(),
      ),
    ),
  );
}

/// The window's one stream, filling it.
class _DeviceWindowHome extends StatelessWidget {
  const _DeviceWindowHome();

  @override
  Widget build(BuildContext context) {
    final entry = context.select<StreamsCubit, StreamEntry?>(
      (c) => c.stateValue.entries.firstOrNull,
    );
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: entry == null
            ? const SizedBox.shrink()
            : StreamTile(entry: entry, mode: StreamTileMode.window),
      ),
    );
  }
}

/// Runs [close] when the window's close button is clicked.
class _OnClose with WindowListener {
  _OnClose(this.close);

  final Future<void> Function() close;

  @override
  void onWindowClose() => unawaited(close());
}
