import 'dart:async';
import 'dart:math';

import 'package:simutil_adb/src/android_device_service.dart';
import 'package:simutil_adb/src/models/adb_connect_result.dart';
import 'package:simutil_adb/src/models/wifi_pairing_device.dart';
import 'package:simutil_adb/src/wifi_discovery_service.dart';

/// Pairs and connects Android 11+ devices over Wi-Fi (wireless debugging)
/// the way Android Studio does: `adb pair`, then find the phone's
/// `_adb-tls-connect._tcp` endpoint on the same host and `adb connect` it,
/// so it shows up as an `ip:port` device.
class AdbWirelessPairing {
  /// Creates a pairing helper over [adb] and [discovery].
  AdbWirelessPairing(this._adb, this._discovery, {Random? random})
    : _random = random ?? Random.secure();

  final AndroidDeviceService _adb;
  final WifiDiscoveryService _discovery;
  final Random _random;

  /// How long to wait for the connect endpoint after pairing.
  static const connectWait = Duration(seconds: 10);

  /// Pairs with the pairing endpoint [pairHostPort] using [code], then
  /// connects to the phone's connect endpoint on the same host.
  Future<AdbConnectResult> pairAndConnect(
    String pairHostPort,
    String code, {
    Duration connectWait = connectWait,
  }) async {
    final paired = await _adb.pairDevice(pairHostPort, code);
    if (!paired.success) return paired;
    final host = pairHostPort.substring(0, pairHostPort.lastIndexOf(':'));
    final endpoint = await firstMatching(
      _discovery.watchConnectDevices(),
      (d) => d.host == host,
      connectWait,
    );
    if (endpoint == null) {
      return const AdbConnectResult(
        success: false,
        message:
            'Paired, but the phone did not offer a connection. Keep Wireless '
            'debugging on, then connect by IP.',
      );
    }
    final connected = await _adb.connectDevice(endpoint.hostPort);
    if (!connected.success) return connected;
    return AdbConnectResult(
      success: true,
      message: 'Connected to ${endpoint.hostPort}',
    );
  }

  /// Starts a QR pairing session: show [QrPairingSession.payload] as a QR
  /// code and await [QrPairingSession.result].
  QrPairingSession startQr() => QrPairingSession._(
    this,
    serviceName: 'simutil-${_randomString(6)}',
    password: _randomString(10),
  );

  String _randomString(int length) {
    const chars = 'abcdefghijkmnpqrstuvwxyz23456789';
    return String.fromCharCodes([
      for (var i = 0; i < length; i++)
        chars.codeUnitAt(_random.nextInt(chars.length)),
    ]);
  }

  /// First event of [stream] passing [test] within [timeout] (or before
  /// [cancel] completes), else null. Always cancels the subscription, which
  /// stops mDNS scanning.
  static Future<WifiPairingDevice?> firstMatching(
    Stream<WifiPairingDevice> stream,
    bool Function(WifiPairingDevice) test,
    Duration timeout, {
    Future<void>? cancel,
  }) async {
    final found = Completer<WifiPairingDevice?>();
    void finish([WifiPairingDevice? device]) {
      if (!found.isCompleted) found.complete(device);
    }

    final timer = Timer(timeout, finish);
    unawaited(cancel?.then((_) => finish()));
    final subscription = stream.listen(
      (device) {
        if (test(device)) finish(device);
      },
      onError: (Object _) {},
      onDone: finish,
    );
    try {
      return await found.future;
    } finally {
      timer.cancel();
      await subscription.cancel();
    }
  }
}

/// One QR pairing attempt: the phone scans [payload] in Developer options
/// › Wireless debugging › Pair device with QR code, then advertises a
/// pairing endpoint named [serviceName].
class QrPairingSession {
  QrPairingSession._(
    this._pairing, {
    required this.serviceName,
    required this.password,
  });

  final AdbWirelessPairing _pairing;

  /// mDNS instance name the phone advertises after scanning.
  final String serviceName;

  /// Pairing password encoded in the QR code.
  final String password;

  final _cancelled = Completer<void>();

  /// The text to encode as a QR code.
  String get payload => 'WIFI:T:ADB;S:$serviceName;P:$password;;';

  /// Waits up to [timeout] for the phone, then pairs and connects.
  /// [onFound] fires once the phone has scanned the code.
  Future<AdbConnectResult> result({
    Duration timeout = const Duration(minutes: 2),
    void Function()? onFound,
  }) async {
    final device = await AdbWirelessPairing.firstMatching(
      _pairing._discovery.watchPairingDevices(),
      (d) => d.name == serviceName,
      timeout,
      cancel: _cancelled.future,
    );
    if (device == null) {
      return AdbConnectResult(
        success: false,
        message: _cancelled.isCompleted
            ? 'Cancelled'
            : 'No phone scanned the code within ${timeout.inMinutes} min',
      );
    }
    onFound?.call();
    return _pairing.pairAndConnect(device.hostPort, password);
  }

  /// Stops waiting for the phone.
  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}
