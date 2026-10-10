# Changelog

## 1.0.0

- Initial release, extracted from the `simutil` app.
- Windows: resolves `adb.exe` / `emulator.exe` and defaults the SDK root to
  `%LOCALAPPDATA%\Android\Sdk`. New `isWindows` test seam on
  `AndroidDeviceService`.
