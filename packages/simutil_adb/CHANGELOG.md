# Changelog

## 1.4.0

- `EmulatorGrpcSession` streams and controls an Android emulator over its
  gRPC API (`streamScreenshot` with the MMAP transport into a caller-owned
  RGB888 file, input through `streamInputEvent`, recording with
  `adb emu screenrecord`), like Android Studio's embedded emulator.
- `EmulatorEndpoint.find(serial)` reads an emulator's gRPC port and token
  from its discovery file (`avd/running/pid_<pid>.ini`).
- `emulatorCameraArgs(back:, front:)` builds `-camera-back` /
  `-camera-front` emulator args from `webcam<N>`, `image:<path>`,
  `video:<path>`, `virtualscene`, `emulated` or `none`; one webcam cannot
  be both cameras.
- `AndroidDeviceService.listWebcams()` lists the host cameras the emulator
  can use (`emulator -webcam-list`).
- `launchDevice(headless: true)` also adds
  `AndroidDeviceService.headlessGpuArgs` (`-gpu host`) unless the caller
  passes `-gpu`: headless emulators otherwise render in software (lavapipe)
  and stream at ~5 fps instead of ~55.
- `ScrcpySession.start` waits (up to 3 min) for `sys.boot_completed` before
  starting the server, which crashed when started on a still-booting
  emulator.

## 1.3.0

- `AndroidAutomation.install` runs `adb install -r -t` and reports the
  `Failure [...]` code. Requires `simutil_core` 1.3.0.
- `ScrcpySession` fails a live stream with `Device disconnected` when the
  server process exits (device unplugged or adb disconnected).

## 1.2.0

- `ScrcpySession.typeText(text)` / `pressKey(keycode, metaState:)` inject
  text and Android key codes over the control socket
  (`ScrcpyProtocol.text`, `ScrcpyProtocol.keycode(..., metaState:)`).
- `ScrcpySession` options `showTouches`, `stayAwake`, `turnScreenOff`
  (`ScrcpyProtocol.displayPower`) and `powerOffOnClose`.
- `AndroidDeviceService.wipeData` deletes an AVD's user data, cache and
  snapshots. Requires `simutil_core` 1.2.0.
- `ScrcpySession` adds the server's own output to the
  `scrcpy server did not start` error (e.g. a version mismatch), and waits
  up to ~10 s (was ~5 s) for a cold emulator to start the server.

## 1.1.0

- `AndroidDeviceService.adbPath` falls back to Homebrew (`/opt/homebrew/bin`,
  `/usr/local/bin`) and winget (`%LOCALAPPDATA%\Microsoft\WinGet\Links`)
  installs before bare `adb` on `PATH`.
- `ScrcpySession` reads video on a worker isolate; `attachDecoder(decode, id)`
  / `detachDecoder(id)` feed a native decoder (a C `decode` function address)
  straight from that isolate. Adds the `ffi` dependency.
- `ScrcpySession` asks the encoder for a key frame every second
  (`video_codec_options=i-frame-interval:int=1`), so a decoder that dropped
  frames recovers within a second instead of up to ~10 s.
- `ScrcpySession.press` handles `DeviceButton.volumeUp` / `volumeDown`
  (`ScrcpyProtocol.keyVolumeUp` / `keyVolumeDown`).
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
- `AndroidAutomation.tapElement` taps a node at its own pixel center with
  `input tap` (works on permission prompts too).
- `AndroidAutomation`: relaunches apps (`am force-stop`, or `pm clear`
  with `clearState`, then `monkey`), types with `input text`
  (ASCII) and reads elements from `uiautomator dump`
  (`parseUiautomatorDump`, normalized to the `wm size` screen so dialogs
  and permission prompts map right).
- Devices carry their Android version in `platform`: emulators from the
  AVD `.ini` target, booted hardware from `ro.build.version.release`
  (`androidPlatformName` maps API levels to versions).

## 1.0.1

- Windows: resolves `adb.exe` / `emulator.exe` and defaults the SDK root to
  `%LOCALAPPDATA%\Android\Sdk`. New `isWindows` test seam on
  `AndroidDeviceService`.

## 1.0.0

- Initial release, extracted from the `simutil` app.
