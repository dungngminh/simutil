import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_app/src/di.dart';
import 'package:simutil_app/src/ui/connect/qr_tab.dart';
import 'package:simutil_app/src/ui/connect/qr_view.dart';
import 'package:simutil_app/src/ui/design/design.dart';

class _Discovery implements WifiDiscoveryService {
  @override
  Stream<WifiPairingDevice> watchPairingDevices() => const Stream.empty();

  @override
  Stream<WifiPairingDevice> watchConnectDevices() => const Stream.empty();
}

class _Adb implements AndroidDeviceService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    getIt.registerSingleton(AdbWirelessPairing(_Adb(), _Discovery()));
  });
  tearDown(getIt.reset);

  testWidgets('QR tab shows a fresh ADB pairing code', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: simuTheme(Brightness.dark),
        home: Scaffold(body: QrTab(onConnected: (_) {})),
      ),
    );

    final qr = tester.widget<QrView>(find.byType(QrView));
    expect(
      qr.data,
      matches(RegExp(r'^WIFI:T:ADB;S:simutil-\w{6};P:\w{10};;$')),
    );
    expect(find.text('Waiting for the phone to scan…'), findsOneWidget);

    // Discovery ended without the phone: a retry gives a new code.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(tester.widget<QrView>(find.byType(QrView)).data, isNot(qr.data));
  });
}
