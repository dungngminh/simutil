# Changelog

## 1.1.0

- `AdbWirelessPairing`: pairs Android 11+ devices over Wi-Fi and connects
  them as `ip:port` (`pairAndConnect`), including QR pairing
  (`startQr()` → `QrPairingSession.payload` / `result()`).
- `WifiDiscoveryService.watchConnectDevices()` discovers
  `_adb-tls-connect._tcp` endpoints.
- `connectDevice` / `disconnectDevice` time out after 15 s and `pairDevice`
  after 30 s (interactive priority) instead of waiting forever.
- `launchDevice(headless: true)` adds `AndroidDeviceService.headlessArgs`
  (`-no-window -no-audio -no-boot-anim`); flags the caller also passes are
  not repeated.
- `deleteSimulator` deletes an AVD (its `.ini` and data directory under
  `avdHome`).
- `watchDevices()` follows `adb track-devices` (reconnecting when the adb
  server restarts) and the AVD directory, instead of polling.
- Device listing (`adb devices`, `emu avd name`, `-list-avds`) runs at
  `CommandPriority.background`; launch and `emu kill` at `interactive`.
- `ScrcpySession`: streams and controls a device through the user's
  installed scrcpy server (`ScrcpyInstall.locate`), exposing H.264 access
  units on `video` (60 fps by default), with recording to
  `.mp4` (remuxed by ffmpeg when available, else `.ts`).
  `requestKeyFrame()` asks for a fresh key frame (at most once a second;
  requests in between are deferred, not dropped). Session setup commands
  run at `CommandPriority.interactive`.

## 1.0.1

- Windows: resolves `adb.exe` / `emulator.exe` and defaults the SDK root to
  `%LOCALAPPDATA%\Android\Sdk`. New `isWindows` test seam on
  `AndroidDeviceService`.

## 1.0.0

- Initial release, extracted from the `simutil` app.
