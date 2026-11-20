# Changelog

## 1.1.1

- `SettingsService` adds missing `theme:` / `last_selected_device_id:` keys
  after a leading `---` instead of above it, which made `settings.yaml` two
  YAML documents (settings and plugins then failed to load).
- `SettingsService` and `AppStateService` write their files atomically
  (temporary file, then rename), so a TUI and a CLI command running at once
  never read an empty file.
- `AppStateService.load` reads each field on its own: one of the wrong type
  no longer drops the others.

## 1.1.0

- `resolveStatePath` falls back to `USERPROFILE` when `HOME` is unset (the
  usual case in Windows shells) instead of the current directory, and
  takes an optional `environment`.
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
