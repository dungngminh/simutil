# Changelog

## 1.1.0

- **Breaking:** removed `ServiceLocator`. Each app now wires its own services
  (the TUI keeps a locator in `simutil`, the desktop app uses `get_it`).
- Dropped the `simutil_adb` and `simutil_apple` dependencies.
- `DeviceChangeWatcher`: reloads device lists when `DeviceService.watchDevices`
  reports a change (debounced), with a slow fallback reload.
- `kReloadInterval` is now the 60 s fallback period (was a 10 s poll).
- `UpdateChecker`: GitHub installs take the newest CLI release (`cli-v*`, or
  legacy `v*`) and skip desktop app releases (`app-v*`).

## 1.0.0

- Initial release, extracted from the `simutil` app.
