# Changelog

## 1.1.0

- `launchDevice(headless: true)` adds `AndroidDeviceService.headlessArgs`
  (`-no-window -no-audio -no-boot-anim`).
- `ScrcpySession`: streams and controls a device through the user's
  installed scrcpy server (`ScrcpyInstall.locate`), serving H.264 as
  MPEG-TS on a loopback `videoUri` (60 fps by default), with recording to
  `.mp4` (remuxed by ffmpeg when available, else `.ts`).

## 1.0.1

- Windows: resolves `adb.exe` / `emulator.exe` and defaults the SDK root to
  `%LOCALAPPDATA%\Android\Sdk`. New `isWindows` test seam on
  `AndroidDeviceService`.

## 1.0.0

- Initial release, extracted from the `simutil` app.
